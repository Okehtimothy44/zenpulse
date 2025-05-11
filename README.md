# ZenPulse

A blockchain-powered meditation app with personalized music, breathing exercises, and user rewards, leveraging Stacks blockchain for transparent and secure user experience tracking.

## Project Overview

ZenPulse is a decentralized application that provides users with a comprehensive meditation experience, leveraging the Stacks blockchain. The key features of the ZenPulse project include:

- Secure and private logging of meditation sessions
- Personalized content recommendations based on mood and preferences
- Advanced tracking of meditation streaks and progress
- Reward token system to incentivize regular meditation practice
- Content marketplace for meditation guides and music

The ZenPulse project consists of four main smart contracts:

1. **User Profile**: Manages user profiles, preferences, and meditation history
2. **Meditation Tracker**: Handles session logging and streak calculations
3. **Zen Token**: Implements the reward token system
4. **Content Registry**: Manages meditation content and recommendations

## Contract Architecture

### User Profile Contract

The `user-profile.clar` contract manages user profiles and preferences, including:

1. **Profile Management**: Create and update user profiles with preferences for breathing patterns, music, and session duration
2. **Session History**: Track individual meditation sessions with detailed metadata
3. **Streak Tracking**: Calculate and maintain user meditation streaks
4. **Data Privacy**: Ensure users maintain control over their personal information

Key data structures:
- `user-profiles`: Stores user preferences and meditation statistics
- `meditation-sessions`: Records individual session details
- `user-session-counters`: Tracks session IDs for each user

### Meditation Tracker Contract

The `meditation-tracker.clar` contract handles meditation session tracking and analytics:

1. **Session Recording**: Log meditation sessions with duration, type, and mood states
2. **Streak Calculation**: Advanced streak tracking with consecutive day bonuses
3. **Statistics**: Track total sessions, minutes meditated, and other metrics
4. **Monthly Analytics**: Generate user statistics for specific time periods

Key features:
- Immutable session records
- Multiple meditation type support
- Mood tracking before and after sessions
- Comprehensive analytics functions

### Zen Token Contract

The `zen-token.clar` contract implements the reward token system:

1. **Token Distribution**: Mint and distribute tokens for completed sessions
2. **Streak Bonuses**: Additional rewards for maintaining streaks
3. **Milestone Rewards**: Special rewards for reaching meditation milestones
4. **Token Redemption**: Exchange tokens for premium content or features

Token mechanics:
- Session completion rewards
- Streak multipliers
- Milestone achievements
- Content marketplace integration

### Content Registry Contract

The `content-registry.clar` contract manages meditation content and recommendations:

1. **Content Management**: Register and verify meditation content
2. **Recommendation System**: Personalized content suggestions based on user preferences
3. **Rating System**: Community-driven content quality assessment
4. **Content Indexing**: Efficient content discovery by mood and type

Features:
- Content verification system
- Mood-based recommendations
- Usage tracking
- Creator attribution

## Installation & Setup

Prerequisites:
- [Clarinet](https://www.npmjs.com/package/clarinet) installed globally

Installation steps:
1. Clone the ZenPulse repository: `git clone https://github.com/example/zenpulse.git`
2. Navigate to the project directory: `cd zenpulse`
3. Install dependencies: `npm install`

## Usage Guide

### Creating a User Profile

```clarity
(contract-call? .user-profile create-profile 
  "John Doe"
  "box"
  "ambient"
  u20)
```

### Recording a Meditation Session

```clarity
(contract-call? .meditation-tracker record-session 
  u30
  "mindfulness"
  "stressed"
  "calm"
  (some u"Great session today"))
```

### Claiming Rewards

```clarity
(contract-call? .zen-token claim-milestone-reward tx-sender)
```

### Finding Meditation Content

```clarity
(contract-call? .content-registry get-recommendations 
  tx-sender 
  MOOD-CALM
  u5)
```

## Testing

The project includes comprehensive test suites for all contracts. To run the tests:

```bash
clarinet test
```

Test coverage includes:
- Profile creation and management
- Session recording and streak calculation
- Token distribution and redemption
- Content recommendation system
- Security and access control

## Security Considerations

The ZenPulse contracts implement several security measures:

1. **Access Control**: Strict function access controls and admin privileges
2. **Input Validation**: Comprehensive validation for all user inputs
3. **Data Privacy**: User control over personal information
4. **Token Security**: Safe token minting and transfer mechanisms
5. **Content Verification**: Multi-step content validation process

The contracts have been designed with security best practices and undergo regular audits to ensure the safety of user data and assets.