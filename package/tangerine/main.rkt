#lang racket/base

; Copyright 2022 Aeva Palecek
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

(require racket/exn)
(require racket/rerequire)
(require ffi/unsafe)
(require racket/sandbox)
(require (only-in syntax/modread with-module-reading-parameterization))

(require "ffi.rkt")
(require "csgst.rkt")
(require "voxel-compiler.rkt")
(require "profiling.rkt")

(provide compile
         align
         paint
         paint-over
         sphere
         ellipsoid
         box
         cube
         torus
         cylinder
         plane
         union
         diff
         inter
         blend
         move
         move-x
         move-y
         move-z
         rotate-x
         rotate-y
         rotate-z
         renderer-load-and-process-model
         renderer-load-untrusted-model)


(define-backend RacketErrorCallback (_fun _string/utf-8 -> _void))


; Used by pretty-print below for operators.
;(define (pretty-print-op head operands)
;  (define tmp (~a "⎛" head))
;  (let* ([treext (string-join operands "\n")]
;         [lines (string-split treext "\n")])
;    (for ([i (in-naturals 1)]
;          [line lines])
;      (let* ([last? (eq? i (length lines))]
;             [sep (if last? "⎝" "⎜")])
;        (set! tmp (string-append tmp "\n" sep "  " line)))))
;  tmp)


; Pretty print the CSG tree for debugging.
;(define (pretty-print csgst)
;  (let ([node (car csgst)])
;    (cond [(or
;            (eq? node 'union)
;            (eq? node 'inter)
;            (eq? node 'diff))
;           (pretty-print-op node (map pretty-print (cdr csgst)))]
;          [(or
;            (eq? node 'blend-union)
;            (eq? node 'blend-inter)
;            (eq? node 'blend-diff))
;           (let ([threshold (cadr csgst)]
;                 [subtrees (cddr csgst)])
;             (pretty-print-op (~a node " " threshold)
;                              (map pretty-print subtrees)))]
;          [else (~a csgst)])))


; This function compiles a CSG tree into a set of partial GLSL sources and
; related parameter data, which is to be later used by tangerine to compose
; shaders and parameter buffers.  Model files should define a function called
; "emit-glsl", which calls this function and returns the results without
; modification.  This allows for checking the validity of the model offline
; without running tangerine.  The functions "bounds-compiler" and "voxel-compiler"
; can be used in place of this function when a specific compiler strategy is
; desired.
(define compile voxel-compiler)


; This is called by the tangerine application to invoke the shape compiler for
; a given model source, and pass the results into the renderer.  The generated
; GLSL will be combined with additional GLSL sources there and passed off to
; OpenGL's GLSL compiler.  If all goes well, the resulting shader object will
; be used to render the model.
(define (renderer-load-and-process-model path-str)
  (profile-scope
   "renderer-load-and-process-model"

   (with-handlers ([exn:fail? (λ (err) (RacketErrorCallback (exn->string err)))])
     (let ([path (string->path path-str)])
       (dynamic-rerequire path)
       (let ([emit-glsl (dynamic-require path 'emit-glsl (λ () #f))]
             [model (dynamic-require path 'model (λ () #f))])
         (cond [emit-glsl (emit-glsl)]
               [model (compile model)]
               [else (error "Module must provide either function 'emit-glsl' or a csgst tree called 'model'.")])))))

  (profile-scope
   "GC"
   (collect-garbage))
  (void))


; Similar to renderer-load-and-process-model, but evaluates the source for a tangerine/smol model in a sandbox.
(define (renderer-load-untrusted-model source)
  (profile-scope
   "renderer-load-untrusted-model"

   (error-print-context-length 0)

   (with-handlers ([exn? (λ (err) (RacketErrorCallback (exn->string err)))])
     (let* ([port (open-input-string source)]
         [stx (begin (port-count-lines! port)
                     (with-module-reading-parameterization
                       (λ () (read-syntax "sandbox" port))))]
         [sandbox (make-module-evaluator stx #:language 'tangerine/smol)]
         [model (call-in-sandbox-context sandbox (λ () (dynamic-require ''anonymous-module 'model (λ () #f))))])
       (if model
           (compile model)
           (error "Invalid model provided.")))))

  (profile-scope
   "GC"
   (collect-garbage))
  (void))
