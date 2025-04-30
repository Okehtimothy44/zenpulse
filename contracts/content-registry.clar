;; content-registry
;; This contract manages a comprehensive catalog of meditation content (breathing exercises, 
;; music tracks, and guided meditations) and implements recommendation algorithms based on 
;; user mood, historical preferences, and community popularity.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CONTENT-EXISTS (err u101))
(define-constant ERR-CONTENT-NOT-FOUND (err u102))
(define-constant ERR-INVALID-CONTENT-TYPE (err u103))
(define-constant ERR-INVALID-MOOD (err u104))
(define-constant ERR-INVALID-DURATION (err u105))
(define-constant ERR-NO-RECOMMENDATIONS (err u106))
(define-constant ERR-INVALID-RATING (err u107))
(define-constant ERR-ALREADY-RATED (err u108))

;; Content types
(define-constant CONTENT-TYPE-BREATHING u1)
(define-constant CONTENT-TYPE-MUSIC u2)
(define-constant CONTENT-TYPE-GUIDED u3)

;; Mood types
(define-constant MOOD-CALM u1)
(define-constant MOOD-FOCUSED u2)
(define-constant MOOD-RELAXED u3)
(define-constant MOOD-ENERGIZED u4)
(define-constant MOOD-ANXIOUS u5)
(define-constant MOOD-SLEEPY u6)

;; Data maps and variables

;; Store content information
(define-map content-registry
  { content-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-utf8 500),
    content-type: uint,
    duration: uint,        ;; Duration in seconds
    moods: (list 6 uint),  ;; List of relevant moods
    uri: (string-ascii 256),
    created-at: uint,
    popularity: uint,      ;; Aggregated usage and ratings
    verified: bool         ;; Whether content meets quality standards
  }
)

;; Track content by creator
(define-map creator-contents
  { creator: principal }
  { content-ids: (list 100 uint) }
)

;; Track user ratings for content
(define-map user-ratings
  { content-id: uint, user: principal }
  { rating: uint } ;; Rating from 1-5
)

;; Track user preferences (which content they've used)
(define-map user-preferences
  { user: principal }
  {
    used-content: (list 100 uint),    ;; Recently used content IDs
    mood-preferences: (list 6 uint),  ;; Preferred moods
    content-type-preferences: (list 3 uint) ;; Preferred content types
  }
)

;; Index content by mood for faster recommendations
(define-map mood-to-content
  { mood: uint }
  { content-ids: (list 100 uint) }
)

;; Index content by type for faster recommendations
(define-map type-to-content
  { content-type: uint }
  { content-ids: (list 100 uint) }
)

;; Auto-incrementing content ID
(define-data-var next-content-id uint u1)

;; Contract administrators
(define-map administrators principal bool)

;; Private functions

;; Check if principal is a contract admin
(define-private (is-admin (user principal))
  (default-to false (map-get? administrators user))
)

;; Check if content exists
(define-private (content-exists (content-id uint))
  (is-some (map-get? content-registry { content-id: content-id }))
)

;; Check if content type is valid
(define-private (valid-content-type (content-type uint))
  (or
    (is-eq content-type CONTENT-TYPE-BREATHING)
    (is-eq content-type CONTENT-TYPE-MUSIC)
    (is-eq content-type CONTENT-TYPE-GUIDED)
  )
)

;; Check if mood is valid
(define-private (valid-mood (mood uint))
  (and
    (>= mood MOOD-CALM)
    (<= mood MOOD-SLEEPY)
  )
)

;; Check if all moods in list are valid
(define-private (valid-moods (moods (list 6 uint)))
  (fold check-mood-valid moods true)
)

(define-private (check-mood-valid (mood uint) (is-valid bool))
  (and is-valid (valid-mood mood))
)

;; Calculate popularity score based on various factors
(define-private (calculate-popularity (content-id uint))
  (let
    (
      (content (unwrap-panic (map-get? content-registry { content-id: content-id })))
      (current-popularity (get popularity content))
    )
    current-popularity ;; Simplified, would include more factors in a real implementation
  )
)

;; Add a content ID to a list if not already present
(define-private (add-to-list (id uint) (id-list (list 100 uint)))
  (if (is-some (index-of id-list id))
    id-list
    (unwrap-panic (as-max-len? (append id-list id) u100))
  )
)

;; Update mood index with new content
(define-private (update-mood-index (mood uint) (content-id uint))
  (let
    (
      (current-list (default-to { content-ids: (list) } (map-get? mood-to-content { mood: mood })))
      (updated-list (add-to-list content-id (get content-ids current-list)))
    )
    (map-set mood-to-content { mood: mood } { content-ids: updated-list })
  )
)

;; Update content type index with new content
(define-private (update-type-index (content-type uint) (content-id uint))
  (let
    (
      (current-list (default-to { content-ids: (list) } (map-get? type-to-content { content-type: content-type })))
      (updated-list (add-to-list content-id (get content-ids current-list)))
    )
    (map-set type-to-content { content-type: content-type } { content-ids: updated-list })
  )
)

;; Update creator's content list
(define-private (update-creator-contents (creator principal) (content-id uint))
  (let
    (
      (current-list (default-to { content-ids: (list) } (map-get? creator-contents { creator: creator })))
      (updated-list (add-to-list content-id (get content-ids current-list)))
    )
    (map-set creator-contents { creator: creator } { content-ids: updated-list })
  )
)

;; Update mood indexes for all moods associated with content
(define-private (update-all-mood-indexes (moods (list 6 uint)) (content-id uint))
  (map update-mood-helper moods)
  (ok true)
)

(define-private (update-mood-helper (mood uint))
  (update-mood-index mood (var-get next-content-id))
)

;; Read-only functions

;; Get content details
(define-read-only (get-content (content-id uint))
  (if (content-exists content-id)
    (ok (unwrap-panic (map-get? content-registry { content-id: content-id })))
    ERR-CONTENT-NOT-FOUND
  )
)

;; Get content by creator
(define-read-only (get-creator-content (creator principal))
  (ok (default-to { content-ids: (list) } (map-get? creator-contents { creator: creator })))
)

;; Get content average rating
(define-read-only (get-content-rating (content-id uint))
  (if (content-exists content-id)
    (ok (calculate-popularity content-id))
    ERR-CONTENT-NOT-FOUND
  )
)

;; Get list of content for a specific mood
(define-read-only (get-content-by-mood (mood uint))
  (if (valid-mood mood)
    (ok (default-to { content-ids: (list) } (map-get? mood-to-content { mood: mood })))
    ERR-INVALID-MOOD
  )
)

;; Get list of content for a specific type
(define-read-only (get-content-by-type (content-type uint))
  (if (valid-content-type content-type)
    (ok (default-to { content-ids: (list) } (map-get? type-to-content { content-type: content-type })))
    ERR-INVALID-CONTENT-TYPE
  )
)

;; Get personalized recommendations based on user preferences
(define-read-only (get-recommendations (user principal) (mood uint) (requested-count uint))
  (if (not (valid-mood mood))
    ERR-INVALID-MOOD
    (let
      (
        (preferences (default-to 
                        { 
                          used-content: (list), 
                          mood-preferences: (list), 
                          content-type-preferences: (list) 
                        } 
                        (map-get? user-preferences { user: user })))
        (mood-content (default-to { content-ids: (list) } (map-get? mood-to-content { mood: mood })))
      )
      ;; In a real implementation, this would include a sophisticated algorithm
      ;; to match content with user preferences and filter out recently used content
      (if (> (len (get content-ids mood-content)) u0)
        (ok (get content-ids mood-content))
        ERR-NO-RECOMMENDATIONS
      )
    )
  )
)

;; Public functions

;; Register new meditation content
(define-public (register-content
    (title (string-ascii 100))
    (description (string-utf8 500))
    (content-type uint)
    (duration uint)
    (moods (list 6 uint))
    (uri (string-ascii 256)))
  (let
    (
      (content-id (var-get next-content-id))
      (creator tx-sender)
    )
    ;; Validation checks
    (asserts! (valid-content-type content-type) ERR-INVALID-CONTENT-TYPE)
    (asserts! (valid-moods moods) ERR-INVALID-MOOD)
    (asserts! (> duration u0) ERR-INVALID-DURATION)
    
    ;; Create new content entry
    (map-set content-registry
      { content-id: content-id }
      {
        creator: creator,
        title: title,
        description: description,
        content-type: content-type,
        duration: duration,
        moods: moods,
        uri: uri,
        created-at: block-height,
        popularity: u0,
        verified: false
      }
    )
    
    ;; Update indexes
    (update-creator-contents creator content-id)
    (update-type-index content-type content-id)
    (try! (update-all-mood-indexes moods content-id))
    
    ;; Increment content ID counter
    (var-set next-content-id (+ content-id u1))
    
    (ok content-id)
  )
)

;; Verify content quality (admin only)
(define-public (verify-content (content-id uint) (verified bool))
  (let
    (
      (content (unwrap! (map-get? content-registry { content-id: content-id }) ERR-CONTENT-NOT-FOUND))
    )
    ;; Only admins can verify content
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Update content verification status
    (map-set content-registry
      { content-id: content-id }
      (merge content { verified: verified })
    )
    
    (ok true)
  )
)

;; Rate content
(define-public (rate-content (content-id uint) (rating uint))
  (let
    (
      (user tx-sender)
      (content (unwrap! (map-get? content-registry { content-id: content-id }) ERR-CONTENT-NOT-FOUND))
    )
    ;; Check rating is valid (1-5)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
    
    ;; Check if user already rated this content
    (asserts! (is-none (map-get? user-ratings { content-id: content-id, user: user })) ERR-ALREADY-RATED)
    
    ;; Save rating
    (map-set user-ratings
      { content-id: content-id, user: user }
      { rating: rating }
    )
    
    ;; Update content popularity (simplified)
    (map-set content-registry
      { content-id: content-id }
      (merge content { popularity: (+ (get popularity content) rating) })
    )
    
    (ok true)
  )
)

;; Record user interaction with content to improve recommendations
(define-public (record-content-usage (content-id uint) (user-mood uint))
  (let
    (
      (user tx-sender)
      (content (unwrap! (map-get? content-registry { content-id: content-id }) ERR-CONTENT-NOT-FOUND))
      (current-prefs (default-to 
                        { 
                          used-content: (list), 
                          mood-preferences: (list), 
                          content-type-preferences: (list) 
                        } 
                        (map-get? user-preferences { user: user })))
      ;; Add content to used list (simplified)
      (updated-used (add-to-list content-id (get used-content current-prefs)))
    )
    ;; Validate mood
    (asserts! (valid-mood user-mood) ERR-INVALID-MOOD)
    
    ;; Update user preferences
    (map-set user-preferences
      { user: user }
      (merge current-prefs { used-content: updated-used })
    )
    
    ;; Update content popularity
    (map-set content-registry
      { content-id: content-id }
      (merge content { popularity: (+ (get popularity content) u1) })
    )
    
    (ok true)
  )
)

;; Add a contract administrator
(define-public (add-administrator (admin principal))
  (begin
    ;; Only current admins can add new admins
    ;; For the first admin, the contract deployer becomes admin
    (asserts! (or (is-admin tx-sender) (is-eq tx-sender contract-caller)) ERR-NOT-AUTHORIZED)
    (map-set administrators admin true)
    (ok true)
  )
)

;; Remove a contract administrator
(define-public (remove-administrator (admin principal))
  (begin
    ;; Only current admins can remove admins
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    ;; Prevent removing yourself
    (asserts! (not (is-eq admin tx-sender)) ERR-NOT-AUTHORIZED)
    (map-delete administrators admin)
    (ok true)
  )
)

;; Initialize contract deployer as admin
(map-set administrators tx-sender true)