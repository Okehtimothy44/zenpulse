;; user-profile
;; This contract manages user profiles, preferences, and meditation history for the ZenPulse meditation app.
;; It enables users to create profiles, update their preferences for breathing patterns, music types, and
;; session durations, and track their meditation history. The data stored here is used to provide
;; personalized recommendations while ensuring user data ownership and privacy.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-ALREADY-EXISTS (err u101))
(define-constant ERR-USER-NOT-FOUND (err u102))
(define-constant ERR-INVALID-PREFERENCE (err u103))
(define-constant ERR-INVALID-SESSION-DURATION (err u104))
(define-constant ERR-INVALID-SESSION-DATA (err u105))

;; Data definitions

;; User profile map: stores basic user information and preferences
(define-map user-profiles
  { user: principal }
  {
    name: (string-ascii 50),
    date-created: uint,
    breathing-preference: (string-ascii 20),  ;; e.g., "4-7-8", "box", "ujjayi"
    music-preference: (string-ascii 20),      ;; e.g., "ambient", "nature", "binaural"
    session-duration-preference: uint,        ;; in minutes
    total-sessions: uint,
    total-minutes: uint,
    streak-days: uint,
    last-session-date: uint
  }
)

;; Session history map: tracks individual meditation sessions
(define-map meditation-sessions
  { user: principal, session-id: uint }
  {
    date: uint,
    duration: uint,                        ;; in minutes
    breathing-type: (string-ascii 20),
    music-type: (string-ascii 20),
    mood-before: (string-ascii 20),
    mood-after: (string-ascii 20),
    notes: (string-utf8 200)
  }
)

;; Track the next available session ID for each user
(define-map user-session-counters
  { user: principal }
  { next-id: uint }
)

;; Private functions

;; Get the next session ID for a user
(define-private (get-next-session-id (user principal))
  (default-to u1
    (get next-id
      (map-get? user-session-counters { user: user })
    )
  )
)

;; Increment the session counter for a user
(define-private (increment-session-counter (user principal))
  (let ((current-id (get-next-session-id user)))
    (map-set user-session-counters
      { user: user }
      { next-id: (+ current-id u1) }
    )
    current-id
  )
)

;; Update user streak based on last session date
(define-private (update-streak (user principal) (current-date uint))
  (let (
    (profile (unwrap! (map-get? user-profiles { user: user }) (tuple)))
    (last-date (default-to u0 (get last-session-date profile)))
    (current-streak (default-to u0 (get streak-days profile)))
    (day-diff (if (> last-date u0)
                (/ (- current-date last-date) u86400) ;; Convert seconds to days
                u0))
    (new-streak (if (is-eq day-diff u1)
                  (+ current-streak u1)  ;; Consecutive day, increment streak
                  (if (> day-diff u1)
                    u1                   ;; Non-consecutive day, reset streak to 1
                    current-streak)))    ;; Same day, maintain streak
  )
    new-streak
  )
)

;; Validate session duration (must be between 1 and 120 minutes)
(define-private (validate-session-duration (duration uint))
  (and (>= duration u1) (<= duration u120))
)

;; Validate breathing preference
(define-private (validate-breathing-preference (preference (string-ascii 20)))
  (or 
    (is-eq preference "4-7-8")
    (is-eq preference "box")
    (is-eq preference "ujjayi")
    (is-eq preference "wim-hof")
    (is-eq preference "pranayama")
    (is-eq preference "custom")
  )
)

;; Validate music preference
(define-private (validate-music-preference (preference (string-ascii 20)))
  (or 
    (is-eq preference "ambient")
    (is-eq preference "nature")
    (is-eq preference "binaural")
    (is-eq preference "silence")
    (is-eq preference "singing-bowls")
    (is-eq preference "custom")
  )
)

;; Read-only functions

;; Get user profile information
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

;; Get specific meditation session
(define-read-only (get-meditation-session (user principal) (session-id uint))
  (map-get? meditation-sessions { user: user, session-id: session-id })
)

;; Get user's total session count
(define-read-only (get-session-count (user principal))
  (default-to u0
    (get total-sessions
      (map-get? user-profiles { user: user })
    )
  )
)

;; Get user's current streak
(define-read-only (get-user-streak (user principal))
  (default-to u0
    (get streak-days
      (map-get? user-profiles { user: user })
    )
  )
)

;; Public functions

;; Create a new user profile
(define-public (create-profile (name (string-ascii 50)) 
                               (breathing-preference (string-ascii 20))
                               (music-preference (string-ascii 20))
                               (session-duration-preference uint))
  (let ((user tx-sender))
    ;; Check if user already exists
    (asserts! (is-none (map-get? user-profiles { user: user })) ERR-USER-ALREADY-EXISTS)
    
    ;; Validate preferences
    (asserts! (validate-breathing-preference breathing-preference) ERR-INVALID-PREFERENCE)
    (asserts! (validate-music-preference music-preference) ERR-INVALID-PREFERENCE)
    (asserts! (validate-session-duration session-duration-preference) ERR-INVALID-SESSION-DURATION)
    
    ;; Create user profile
    (map-set user-profiles
      { user: user }
      {
        name: name,
        date-created: block-height,
        breathing-preference: breathing-preference,
        music-preference: music-preference,
        session-duration-preference: session-duration-preference,
        total-sessions: u0,
        total-minutes: u0,
        streak-days: u0,
        last-session-date: u0
      }
    )
    
    ;; Initialize session counter
    (map-set user-session-counters
      { user: user }
      { next-id: u1 }
    )
    
    (ok true)
  )
)

;; Update user profile preferences
(define-public (update-preferences (breathing-preference (string-ascii 20))
                                  (music-preference (string-ascii 20))
                                  (session-duration-preference uint))
  (let ((user tx-sender))
    ;; Check if user exists
    (asserts! (is-some (map-get? user-profiles { user: user })) ERR-USER-NOT-FOUND)
    
    ;; Validate preferences
    (asserts! (validate-breathing-preference breathing-preference) ERR-INVALID-PREFERENCE)
    (asserts! (validate-music-preference music-preference) ERR-INVALID-PREFERENCE)
    (asserts! (validate-session-duration session-duration-preference) ERR-INVALID-SESSION-DURATION)
    
    ;; Get current profile
    (let ((current-profile (unwrap-panic (map-get? user-profiles { user: user }))))
      ;; Update only preferences, keeping other data intact
      (map-set user-profiles
        { user: user }
        (merge current-profile {
          breathing-preference: breathing-preference,
          music-preference: music-preference,
          session-duration-preference: session-duration-preference
        })
      )
      
      (ok true)
    )
  )
)

;; Record a completed meditation session
(define-public (record-meditation-session (duration uint)
                                         (breathing-type (string-ascii 20))
                                         (music-type (string-ascii 20))
                                         (mood-before (string-ascii 20))
                                         (mood-after (string-ascii 20))
                                         (notes (string-utf8 200)))
  (let ((user tx-sender)
        (current-time block-height))
    
    ;; Check if user exists
    (asserts! (is-some (map-get? user-profiles { user: user })) ERR-USER-NOT-FOUND)
    
    ;; Validate input data
    (asserts! (validate-session-duration duration) ERR-INVALID-SESSION-DURATION)
    (asserts! (validate-breathing-preference breathing-type) ERR-INVALID-PREFERENCE)
    (asserts! (validate-music-preference music-type) ERR-INVALID-PREFERENCE)
    
    ;; Get current profile
    (let ((current-profile (unwrap-panic (map-get? user-profiles { user: user })))
          (session-id (increment-session-counter user))
          (new-streak (update-streak user current-time)))
      
      ;; Record the meditation session
      (map-set meditation-sessions
        { user: user, session-id: session-id }
        {
          date: current-time,
          duration: duration,
          breathing-type: breathing-type,
          music-type: music-type,
          mood-before: mood-before,
          mood-after: mood-after,
          notes: notes
        }
      )
      
      ;; Update user profile stats
      (map-set user-profiles
        { user: user }
        (merge current-profile {
          total-sessions: (+ (get total-sessions current-profile) u1),
          total-minutes: (+ (get total-minutes current-profile) duration),
          streak-days: new-streak,
          last-session-date: current-time
        })
      )
      
      (ok session-id)
    )
  )
)

;; Update user name
(define-public (update-name (new-name (string-ascii 50)))
  (let ((user tx-sender))
    ;; Check if user exists
    (asserts! (is-some (map-get? user-profiles { user: user })) ERR-USER-NOT-FOUND)
    
    ;; Get current profile
    (let ((current-profile (unwrap-panic (map-get? user-profiles { user: user }))))
      ;; Update only name, keeping other data intact
      (map-set user-profiles
        { user: user }
        (merge current-profile { name: new-name })
      )
      
      (ok true)
    )
  )
)

;; Delete a meditation session (optional feature for privacy)
(define-public (delete-meditation-session (session-id uint))
  (let ((user tx-sender))
    ;; Check if session exists and belongs to user
    (asserts! (is-some (map-get? meditation-sessions { user: user, session-id: session-id })) ERR-INVALID-SESSION-DATA)
    
    ;; Delete the session
    (map-delete meditation-sessions { user: user, session-id: session-id })
    
    ;; Note: we're not updating total stats since this would require recalculating from all sessions
    ;; This is a design decision to keep things simple
    
    (ok true)
  )
)