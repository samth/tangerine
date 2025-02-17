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


(require tangerine)
(require tangerine/eval)
(provide emit-glsl)


(define (emit-glsl)
  (define csgst (diff (inter (cube 4) (sphere 5.5))
                      (cylinder 3 5)
                      (rotate-x 90 (cylinder 3 5))
                      (rotate-y 90 (cylinder 3 5))))
  (compile csgst))
