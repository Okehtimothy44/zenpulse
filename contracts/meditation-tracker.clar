;; meditation-tracker
;; 
;; This contract enables users to record their meditation sessions, including duration, type, 
;; and mood states before and after practice. It provides immutable tracking of a user's meditation 
;; journey while calculating consistency metrics like streak days and total meditation time.
;; These metrics can be used for personalization and rewards within the ZenPulse meditation app.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-DURATION (err u101))
(define-constant ERR-INVALID-TYPE (err u102))
(define-constant ERR-INVALID-MOOD (err u103))
(define-constant ERR-SESSION-NOT-FOUND (err u104))
(define-constant ERR-ALREADY-RECORDED-TODAY (err u105))

;; Constants
(define-constant MEDITATION-TYPES (list "mindfulness" "focused" "loving-kindness" "body-scan" "transcendental" "zen" "yoga" "custom"))
(define-constant MOOD-STATES (list "anxious" "stressed" "neutral" "calm" "peaceful" "joyful" "grateful" "energized" "focused"))
(define-constant SECONDS-IN-DAY u86400)

;; Data structures
;; Stores user's meditation sessions
(define-map user-sessions
  { user: principal }
  { 
    total-sessions: uint,
    total-minutes: uint,
    current-streak: uint,
    longest-streak: uint,
    last-session-day: uint
  }
)

;; Stores individual meditation session data
(define-map sessions
  { user: principal, session-id: uint }
  {
    timestamp: uint,
    duration: uint, ;; in minutes
    meditation-type: (string-ascii 20),
    mood-before: (string-ascii 20),
    mood-after: (string-ascii 20),
    notes: (optional (string-utf8 280))
  }
)

;; Private functions
(define-private (is-valid-type (meditation-type (string-ascii 20)))
  (is-some (index-of MEDITATION-TYPES meditation-type))
)

(define-private (is-valid-mood (mood (string-ascii 20)))
  (is-some (index-of MOOD-STATES mood))
)

(define-private (get-current-day-number)
  ;; Convert current block time to days since epoch
  (/ (unwrap-panic (get-block-info? time block-height)) SECONDS-IN-DAY)
)

(define-private (update-streak (user principal) (current-day uint) (last-session-day uint))
  (let (
    (user-data (default-to 
      { 
        total-sessions: u0,
        total-minutes: u0,
        current-streak: u0,
        longest-streak: u0,
        last-session-day: u0
      } 
      (map-get? user-sessions { user: user })
    ))
    (current-streak (get current-streak user-data))
    (longest-streak (get longest-streak user-data))
  )
    (if (is-eq (+ last-session-day u1) current-day)
      ;; Consecutive day - continue streak
      (let (
        (new-streak (+ current-streak u1))
        (new-longest-streak (if (> new-streak longest-streak) new-streak longest-streak))
      )
        { 
          current-streak: new-streak,
          longest-streak: new-longest-streak
        }
      )
      ;; Non-consecutive day - reset streak
      { 
        current-streak: u1,
        longest-streak: longest-streak
      }
    )
  )
)

;; Public functions
(define-public (record-session 
  (duration uint) 
  (meditation-type (string-ascii 20)) 
  (mood-before (string-ascii 20)) 
  (mood-after (string-ascii 20))
  (notes (optional (string-utf8 280)))
)
  (let (
    (user tx-sender)
    (current-day (get-current-day-number))
    (user-data (default-to 
      { 
        total-sessions: u0,
        total-minutes: u0,
        current-streak: u0,
        longest-streak: u0,
        last-session-day: u0
      } 
      (map-get? user-sessions { user: user })
    ))
    (total-sessions (get total-sessions user-data))
    (next-session-id (+ total-sessions u1))
    (last-session-day (get last-session-day user-data))
  )
    ;; Input validation
    (asserts! (> duration u0) ERR-INVALID-DURATION)
    (asserts! (is-valid-type meditation-type) ERR-INVALID-TYPE)
    (asserts! (is-valid-mood mood-before) ERR-INVALID-MOOD)
    (asserts! (is-valid-mood mood-after) ERR-INVALID-MOOD)
    (asserts! (not (is-eq last-session-day current-day)) ERR-ALREADY-RECORDED-TODAY)
    
    ;; Calculate streak updates
    (let (
      (streak-updates (update-streak user current-day last-session-day))
      (new-streak (get current-streak streak-updates))
      (new-longest-streak (get longest-streak streak-updates))
    )
      ;; Update session data
      (map-set sessions 
        { user: user, session-id: next-session-id }
        {
          timestamp: block-height,
          duration: duration,
          meditation-type: meditation-type,
          mood-before: mood-before,
          mood-after: mood-after,
          notes: notes
        }
      )
      
      ;; Update user metrics
      (map-set user-sessions
        { user: user }
        {
          total-sessions: next-session-id,
          total-minutes: (+ (get total-minutes user-data) duration),
          current-streak: new-streak,
          longest-streak: new-longest-streak,
          last-session-day: current-day
        }
      )
      
      (ok next-session-id)
    )
  )
)

;; Read-only functions
(define-read-only (get-user-stats (user principal))
  (default-to 
    { 
      total-sessions: u0,
      total-minutes: u0,
      current-streak: u0,
      longest-streak: u0,
      last-session-day: u0
    } 
    (map-get? user-sessions { user: user })
  )
)

(define-read-only (get-session (user principal) (session-id uint))
  (match (map-get? sessions { user: user, session-id: session-id })
    session-data (ok session-data)
    ERR-SESSION-NOT-FOUND
  )
)

(define-read-only (check-streak-active (user principal))
  (let (
    (user-data (get-user-stats user))
    (last-session-day (get last-session-day user-data))
    (current-day (get-current-day-number))
  )
    (or 
      ;; First check if they've meditated today
      (is-eq last-session-day current-day)
      ;; Then check if they meditated yesterday
      (is-eq last-session-day (- current-day u1))
    )
  )
)

(define-read-only (get-stats-for-month (user principal) (year uint) (month uint))
  ;; This is a stub implementation - in a real contract, we would iterate through
  ;; user sessions to find those in a specific month
  ;; Due to Clarity's limitations, this would require client-side filtering
  ;; or a more complex implementation pattern
  (get-user-stats user)
)