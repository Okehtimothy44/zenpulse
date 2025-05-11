;; ZenPulse Meditation Sessions Smart Contract
;; A blockchain-powered meditation tracking and rewards system
;; Features:
;; - Log and validate meditation sessions
;; - Track user meditation streaks and progress
;; - Implement secure reward token mechanism

;; Error Codes
(define-constant ERR_UNAUTHORIZED u403)
(define-constant ERR_INVALID_SESSION u400)
(define-constant ERR_DUPLICATE_SESSION u409)
(define-constant ERR_REWARD_CALCULATION_FAILED u500)

;; Constants
(define-constant MAX_SESSION_LENGTH u120)  ;; Maximum session length (minutes)
(define-constant REWARD_STREAK_THRESHOLD u7)  ;; Streak for rewards
(define-constant WEEKLY_REWARD_AMOUNT u10)  ;; Reward tokens per week

;; Session Data Map
;; Tracks individual meditation sessions per user
(define-map meditation-sessions 
  {
    user: principal,
    timestamp: uint
  }
  {
    duration: uint,
    meditation-type: (string-ascii 20)
  }
)

;; User Streak Tracking
(define-map user-streaks 
  principal 
  {
    current-streak: uint,
    last-session-timestamp: uint
  }
)

;; Reward Token Tracking
(define-map user-rewards 
  principal 
  {
    total-tokens: uint,
    last-reward-week: uint
  }
)

;; Private Functions

;; Validate meditation session parameters
(define-private (validate-session-params (duration uint) (meditation-type (string-ascii 20)))
  (and 
    (> duration u0)
    (<= duration MAX_SESSION_LENGTH)
    (> (len meditation-type) u0)
  )
)

;; Calculate user streak
(define-private (update-user-streak (user principal) (current-block uint))
  (let 
    ((current-streak-info (default-to 
      {current-streak: u0, last-session-timestamp: u0} 
      (map-get? user-streaks user)))
     (last-session-block (get last-session-timestamp current-streak-info))
     (current-streak (get current-streak current-streak-info))
     (blocks-per-day u144) ;; Approximate blocks per day
    )
    ;; Logic to increment or reset streak based on block intervals
    (if (or 
          (is-eq last-session-block u0)
          (>= (- current-block last-session-block) blocks-per-day)
        )
        {
          current-streak: (+ current-streak u1),
          last-session-timestamp: current-block
        }
        current-streak-info)
  )
)

;; Calculate and distribute weekly rewards
(define-private (calculate-weekly-reward (user principal) (current-streak uint))
  (if (>= current-streak REWARD_STREAK_THRESHOLD)
      (let 
        ((current-rewards (default-to 
          {total-tokens: u0, last-reward-week: u0} 
          (map-get? user-rewards user)))
         (current-week (/ block-height u1008)) ;; Approximately one week (using block height)
        )
        (if (not (is-eq (get last-reward-week current-rewards) current-week))
            {
              total-tokens: (+ (get total-tokens current-rewards) WEEKLY_REWARD_AMOUNT),
              last-reward-week: current-week
            }
            current-rewards)
        current-rewards)
  )
)

;; Public Functions

;; Log a meditation session
(define-public (log-meditation-session 
  (duration uint) 
  (meditation-type (string-ascii 20))
)
  (let 
    ((user tx-sender)
     (current-block block-height)
    )
    ;; Validate session parameters
    (asserts! 
      (validate-session-params duration meditation-type) 
      (err ERR_INVALID_SESSION)
    )

    ;; Prevent duplicate session logging within the same block
    (asserts! 
      (is-none 
        (map-get? meditation-sessions 
          {user: user, timestamp: current-block}
        )
      ) 
      (err ERR_DUPLICATE_SESSION)
    )

    ;; Log meditation session
    (map-set meditation-sessions 
      {user: user, timestamp: current-block} 
      {duration: duration, meditation-type: meditation-type}
    )

    ;; Update user streak
    (let 
      ((updated-streak (update-user-streak user current-block))
       (weekly-reward (calculate-weekly-reward user (get current-streak updated-streak)))
      )
      ;; Update streak and rewards
      (map-set user-streaks user updated-streak)
      (map-set user-rewards user weekly-reward)

      (ok {
        session-logged: true,
        current-streak: (get current-streak updated-streak),
        weekly-reward-tokens: (get total-tokens weekly-reward)
      })
    )
  )
)

;; Read-only Functions

;; Get user's current meditation streak
(define-read-only (get-user-streak (user principal))
  (map-get? user-streaks user)
)

;; Get user's total reward tokens
(define-read-only (get-user-rewards (user principal))
  (map-get? user-rewards user)
)

;; Get a specific meditation session
(define-read-only (get-meditation-session (user principal) (timestamp uint))
  (map-get? meditation-sessions {user: user, timestamp: timestamp})
)