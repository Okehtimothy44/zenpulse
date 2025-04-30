;; zen-token
;; Manages the ZenToken reward system for incentivizing regular meditation practices

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MINT-FAILED (err u101))
(define-constant ERR-TRANSFER-FAILED (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-ALREADY-CLAIMED (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-USER-NOT-FOUND (err u106))
(define-constant ERR-REDEMPTION-FAILED (err u107))
(define-constant ERR-STREAK-ALREADY-UPDATED (err u108))

;; Token Configuration
(define-fungible-token zen-token)
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TOKEN-NAME "ZenToken")
(define-constant TOKEN-SYMBOL "ZEN")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-URI "https://zenpulse.app/token-metadata")

;; Meditation Session Rewards
(define-constant SESSION-COMPLETION-REWARD u10) ;; 10 tokens per completed session
(define-constant STREAK-BONUS-FACTOR u1)        ;; 1 additional token per day in streak
(define-constant MILESTONE-REWARD u100)         ;; 100 tokens for reaching milestones

;; User Data
(define-map user-balances principal uint)
(define-map user-meditation-streaks principal uint)
(define-map user-total-sessions principal uint)
(define-map user-last-meditation-date principal uint)
(define-map daily-reward-claims { user: principal, date: uint } bool)
(define-map milestone-claims { user: principal, milestone: uint } bool)

;; Token Metadata
(define-read-only (get-name)
  TOKEN-NAME
)

(define-read-only (get-symbol)
  TOKEN-SYMBOL
)

(define-read-only (get-decimals)
  TOKEN-DECIMALS
)

(define-read-only (get-token-uri)
  TOKEN-URI
)

;; Balance Management Functions
(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-total-supply)
  (ft-get-supply zen-token)
)

;; Meditation Tracking Functions
(define-read-only (get-streak (user principal))
  (default-to u0 (map-get? user-meditation-streaks user))
)

(define-read-only (get-total-sessions (user principal))
  (default-to u0 (map-get? user-total-sessions user))
)

(define-read-only (get-last-meditation-date (user principal))
  (default-to u0 (map-get? user-last-meditation-date user))
)

(define-read-only (has-claimed-daily-reward (user principal) (date uint))
  (default-to false (map-get? daily-reward-claims { user: user, date: date }))
)

(define-read-only (has-claimed-milestone (user principal) (milestone uint))
  (default-to false (map-get? milestone-claims { user: user, milestone: milestone }))
)

;; Check if user's streak should be broken based on last meditation date
(define-private (should-break-streak (user principal) (current-date uint))
  (let (
    (last-date (get-last-meditation-date user))
  )
    (if (> last-date u0)
      (> (- current-date last-date) u1) ;; Break streak if more than 1 day has passed
      false
    )
  )
)

;; Helper function to calculate streak bonus
(define-private (calculate-streak-bonus (streak uint))
  (* streak STREAK-BONUS-FACTOR)
)

;; Helper function to calculate milestone rewards
(define-private (calculate-milestone-reward (session-count uint))
  (if (and (> session-count u0) (is-eq (mod session-count u10) u0))
    MILESTONE-REWARD
    u0
  )
)

;; Token Management Functions

;; Mint tokens to a user (only contract owner)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (ft-mint? zen-token amount recipient)
  )
)

;; Transfer tokens between users
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get-balance sender)) ERR-INSUFFICIENT-BALANCE)
    (ft-transfer? zen-token amount sender recipient)
  )
)

;; Record a completed meditation session and award tokens
(define-public (record-meditation-session (user principal) (date uint) (duration uint))
  (begin
    ;; Only the user themselves or the contract owner can record sessions
    (asserts! (or (is-eq tx-sender user) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    
    ;; Ensure not already claimed for today
    (asserts! (not (has-claimed-daily-reward user date)) ERR-ALREADY-CLAIMED)
    
    ;; Update user's total session count
    (let (
      (current-sessions (get-total-sessions user))
      (new-session-count (+ current-sessions u1))
      (streak (get-streak user))
      (last-date (get-last-meditation-date user))
    )
      ;; Update streak
      (if (should-break-streak user date)
        (map-set user-meditation-streaks user u1) ;; Reset streak to 1
        (map-set user-meditation-streaks user (+ streak u1)) ;; Increment streak
      )
      
      ;; Update last meditation date
      (map-set user-last-meditation-date user date)
      
      ;; Update total sessions
      (map-set user-total-sessions user new-session-count)
      
      ;; Mark daily reward as claimed
      (map-set daily-reward-claims { user: user, date: date } true)
      
      ;; Calculate and award tokens
      (let (
        (updated-streak (get-streak user))
        (base-reward SESSION-COMPLETION-REWARD)
        (streak-bonus (calculate-streak-bonus updated-streak))
        (total-reward (+ base-reward streak-bonus))
      )
        (ft-mint? zen-token total-reward user)
      )
    )
  )
)

;; Claim milestone rewards
(define-public (claim-milestone-reward (user principal))
  (begin
    ;; Only the user themselves can claim their milestone rewards
    (asserts! (is-eq tx-sender user) ERR-NOT-AUTHORIZED)
    
    (let (
      (session-count (get-total-sessions user))
      (milestone (/ session-count u10))
    )
      ;; Ensure there's a milestone to claim and it hasn't been claimed yet
      (asserts! (> milestone u0) ERR-INVALID-AMOUNT)
      (asserts! (is-eq (mod session-count u10) u0) ERR-INVALID-AMOUNT)
      (asserts! (not (has-claimed-milestone user milestone)) ERR-ALREADY-CLAIMED)
      
      ;; Mark milestone as claimed
      (map-set milestone-claims { user: user, milestone: milestone } true)
      
      ;; Mint milestone reward tokens
      (ft-mint? zen-token MILESTONE-REWARD user)
    )
  )
)

;; Redeem tokens for premium content or features
(define-public (redeem-tokens (user principal) (amount uint) (content-id (string-ascii 50)))
  (begin
    ;; Only the user themselves can redeem their tokens
    (asserts! (is-eq tx-sender user) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get-balance user)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Burn tokens (or transfer to content provider in a real implementation)
    (ft-burn? zen-token amount user)
  )
)

;; Initialize the token - must be called once at deployment
(define-public (initialize-token)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ft-mint? zen-token u1000000000 CONTRACT-OWNER) ;; Mint initial supply to contract owner
  )
)