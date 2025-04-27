# ZenPulse

A blockchain-powered meditation app with personalized music, breathing exercises, and user rewards.

## Project Overview

ZenPulse is a decentralized application that aims to provide users with a comprehensive meditation experience, leveraging the Stacks blockchain. The key features of the ZenPulse project include:

- Secure and private logging of meditation sessions
- Tracking of user meditation streaks and progress
- Personalized music recommendations and breathing techniques
- Reward token system to incentivize regular meditation practice

The ZenPulse project is composed of two main smart contracts:

1. **ZenPulse Sessions**: Responsible for managing meditation session logging, streak tracking, and reward distribution.
2. **ZenPulse Profile**: Handles user profile creation, updates, and mood history tracking.

## Contract Architecture

### ZenPulse Sessions Contract

The `zenpulse-sessions.clar` contract is responsible for managing the ZenPulse meditation sessions, including:

1. **Session Logging**: The `log-meditation-session` function allows users to log their meditation sessions, validating the session parameters and preventing duplicate entries.
2. **Streak Tracking**: The `update-user-streak` private function calculates the user's current meditation streak based on the time between sessions.
3. **Reward Distribution**: The `calculate-weekly-reward` private function determines if the user has met the streak threshold for receiving weekly reward tokens, updating the user's reward balance accordingly.
4. **Read-only Functions**: The contract provides read-only functions to retrieve the user's current streak, total reward tokens, and details of a specific meditation session.

The contract uses the following data structures:

- `meditation-sessions`: A map that stores the details of each user's meditation sessions, keyed by the user principal and session timestamp.
- `user-streaks`: A map that tracks the current meditation streak and the timestamp of the last session for each user.
- `user-rewards`: A map that stores the total reward tokens earned and the last week the user received a reward for each user.

### ZenPulse Profile Contract

The `zenpulse-profile.clar` contract is responsible for managing the user profiles for the ZenPulse application, including:

1. **Profile Creation and Updates**: The `create-or-update-profile` function allows users to create a new profile or update an existing one. It includes input validation to ensure the data conforms to the specified constraints.
2. **Mood History Tracking**: The profile stores a list of the user's recent moods, with a maximum size of 10 entries.
3. **Total Meditation Minutes Tracking**: The profile stores the total number of meditation minutes a user has logged, which can be updated using the `update-meditation-minutes` function.
4. **Read-only Functions**: The contract provides read-only functions to retrieve the user's full profile and their total meditation minutes.

The contract uses a single data structure, the `user-profiles` map, to store the user profile information, keyed by the user's principal.

## Installation & Setup

Prerequisites:
- [Clarinet](https://www.npmjs.com/package/clarinet) installed globally

Installation steps:
1. Clone the ZenPulse repository: `git clone https://github.com/example/zenpulse.git`
2. Navigate to the project directory: `cd zenpulse`
3. Install dependencies: `npm install`

Configuration:
- The project includes Clarinet configuration files for different deployment environments (Devnet, Mainnet, Testnet) in the `settings/` directory.
- Modify the appropriate configuration file to set up your deployment environment.

## Usage Guide

### Logging a Meditation Session

To log a meditation session, call the `log-meditation-session` function on the `zenpulse-sessions` contract, providing the session duration and meditation type:

```clarity
(contract-call? 'zenpulse-sessions log-meditation-session u30 "Mindfulness")
```

This will log the meditation session, update the user's streak, and potentially distribute weekly reward tokens.

### Retrieving User Information

To retrieve a user's current meditation streak, call the `get-user-streak` read-only function on the `zenpulse-sessions` contract:

```clarity
(contract-call? 'zenpulse-sessions get-user-streak 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

To retrieve a user's total reward tokens, call the `get-user-rewards` read-only function on the `zenpulse-sessions` contract:

```clarity
(contract-call? 'zenpulse-sessions get-user-rewards 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Managing User Profiles

To create or update a user profile, call the `create-or-update-profile` function on the `zenpulse-profile` contract, providing the necessary parameters:

```clarity
(contract-call? 'zenpulse-profile create-or-update-profile u30 u7 "Jazz" "Calm" "Zen")
```

To retrieve a user's profile, call the `get-user-profile` read-only function on the `zenpulse-profile` contract:

```clarity
(contract-call? 'zenpulse-profile get-user-profile 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Testing

The ZenPulse project includes comprehensive test suites for both the `zenpulse-sessions` and `zenpulse-profile` contracts, covering the following scenarios:

- Logging meditation sessions and handling invalid inputs
- Calculating and updating user streaks
- Distributing weekly reward tokens
- Creating and updating user profiles with valid and invalid inputs
- Tracking user mood history

To run the tests, use the Clarinet CLI:

```bash
clarinet test
```

## Security Considerations

The ZenPulse contracts include several security measures:

1. **Input Validation**: All public functions validate the input parameters to ensure they conform to the expected constraints, rejecting invalid data.
2. **Duplicate Session Prevention**: The `log-meditation-session` function checks for and rejects attempts to log the same session twice within the same block.
3. **Permissions and Authorization**: The contracts only allow the transaction sender (the user) to perform actions on their own data, ensuring secure access control.
4. **Data Integrity**: The contracts use Clarity's built-in data types and data structures to maintain the integrity of stored information, such as user profiles and meditation sessions.

Additionally, the contracts have been thoroughly tested to ensure their correct behavior and resilience against common security vulnerabilities.
