;; ZenPulse User Profile Smart Contract
;; Manages user meditation profiles with secure access control

;; Error Codes
(define-constant ERR_UNAUTHORIZED u403)
(define-constant ERR_INVALID_INPUT u400)
(define-constant ERR_PROFILE_NOT_FOUND u404)

;; Constants for Validation
(define-constant MAX_MOOD_LENGTH u50)
(define-constant MAX_MUSIC_STYLE_LENGTH u30)
(define-constant MAX_BREATHING_TECHNIQUE_LENGTH u30)

;; User Profile Map
(define-map user-profiles 
  principal 
  {
    total-meditation-minutes: uint,
    relaxation-level: uint,
    music-style: (string-ascii MAX_MUSIC_STYLE_LENGTH),
    mood-history: (list 10 (string-ascii MAX_MOOD_LENGTH)),
    breathing-technique: (string-ascii MAX_BREATHING_TECHNIQUE_LENGTH)
  }
)

;; Validate Input Data
(define-private (is-valid-relaxation-level (level uint))
  (and (>= level u1) (<= level u10))
)

(define-private (is-valid-music-style (style (string-ascii MAX_MUSIC_STYLE_LENGTH)))
  (> (len style) u0)
)

(define-private (is-valid-breathing-technique (technique (string-ascii MAX_BREATHING_TECHNIQUE_LENGTH)))
  (> (len technique) u0)
)

;; Create or Update User Profile
(define-public (create-or-update-profile
  (total-minutes uint)
  (relaxation-level uint)
  (music-style (string-ascii MAX_MUSIC_STYLE_LENGTH))
  (mood (string-ascii MAX_MOOD_LENGTH))
  (breathing-technique (string-ascii MAX_BREATHING_TECHNIQUE_LENGTH))
)
  (begin
    ;; Input Validation
    (asserts! (is-valid-relaxation-level relaxation-level) (err ERR_INVALID_INPUT))
    (asserts! (is-valid-music-style music-style) (err ERR_INVALID_INPUT))
    (asserts! (is-valid-breathing-technique breathing-technique) (err ERR_INVALID_INPUT))

    ;; Retrieve existing profile or create empty list for mood history
    (let ((existing-profile (map-get? user-profiles tx-sender))
          (updated-mood-history 
            (match existing-profile
              profile 
                (if (< (len (get mood-history profile)) u10)
                    (unwrap! (as-max-len? (append (get mood-history profile) mood) u10) (err ERR_INVALID_INPUT))
                    (unwrap! (as-max-len? (append (list) mood) u10) (err ERR_INVALID_INPUT))
                )
              ;; If no existing profile, create a new list
              (unwrap! (as-max-len? (list mood) u10) (err ERR_INVALID_INPUT))
            )
          )
         )
      
      ;; Set the updated or new profile
      (map-set user-profiles tx-sender {
        total-meditation-minutes: total-minutes,
        relaxation-level: relaxation-level,
        music-style: music-style,
        mood-history: updated-mood-history,
        breathing-technique: breathing-technique
      })
      
      (ok true)
    )
  )
)

;; Get User Profile (Read-Only)
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles user)
)

;; Get Total Meditation Minutes (Read-Only)
(define-read-only (get-total-meditation-minutes (user principal))
  (match (map-get? user-profiles user)
    profile (some (get total-meditation-minutes profile))
    none
  )
)

;; Update Meditation Minutes
(define-public (update-meditation-minutes (additional-minutes uint))
  (let ((current-profile (unwrap! (map-get? user-profiles tx-sender) (err ERR_PROFILE_NOT_FOUND))))
    (map-set user-profiles tx-sender 
      (merge current-profile {
        total-meditation-minutes: (+ (get total-meditation-minutes current-profile) additional-minutes)
      })
    )
    (ok true)
  )
)