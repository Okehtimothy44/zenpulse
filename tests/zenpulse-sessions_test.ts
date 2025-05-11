import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.2/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Sessions Contract: Log meditation session successfully",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get("wallet_1")!;
    const block = chain.mineBlock([
      Tx.contractCall(
        "zenpulse-sessions", 
        "log-meditation-session", 
        [
          types.uint(30),           // duration
          types.ascii("Mindfulness") // meditation type
        ],
        user.address
      )
    ]);

    const result = block.receipts[0].result.expectOk();
    result.expectTuple({
      "session-logged": types.bool(true),
      "current-streak": types.uint(1),
      "weekly-reward-tokens": types.uint(0)
    });
  },
});

Clarinet.test({
  name: "Sessions Contract: Prevent duplicate session logging",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get("wallet_1")!;
    
    // First, log a valid session
    chain.mineBlock([
      Tx.contractCall(
        "zenpulse-sessions", 
        "log-meditation-session", 
        [
          types.uint(30),           // duration
          types.ascii("Mindfulness") // meditation type
        ],
        user.address
      )
    ]);

    // Try to log the same session again
    const block = chain.mineBlock([
      Tx.contractCall(
        "zenpulse-sessions", 
        "log-meditation-session", 
        [
          types.uint(30),           // duration
          types.ascii("Mindfulness") // meditation type
        ],
        user.address
      )
    ]);

    block.receipts[0].result.expectErr().expectUint(409); // ERR_DUPLICATE_SESSION
  },
});

Clarinet.test({
  name: "Sessions Contract: Invalid session parameters",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get("wallet_1")!;
    const invalidTests = [
      {
        name: "Zero duration",
        args: [types.uint(0), types.ascii("Mindfulness")],
        expectedError: 400
      },
      {
        name: "Excessive duration",
        args: [types.uint(200), types.ascii("Mindfulness")],
        expectedError: 400
      },
      {
        name: "Empty meditation type",
        args: [types.uint(30), types.ascii("")],
        expectedError: 400
      }
    ];

    for (const test of invalidTests) {
      const block = chain.mineBlock([
        Tx.contractCall(
          "zenpulse-sessions", 
          "log-meditation-session", 
          test.args,
          user.address
        )
      ]);

      block.receipts[0].result.expectErr().expectUint(test.expectedError);
    }
  },
});

Clarinet.test({
  name: "Sessions Contract: User streak calculation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get("wallet_1")!;
    
    // Log multiple sessions to build streak
    for (let i = 0; i < 10; i++) {
      chain.mineBlock([
        Tx.contractCall(
          "zenpulse-sessions", 
          "log-meditation-session", 
          [
            types.uint(30),           // duration
            types.ascii("Mindfulness") // meditation type
          ],
          user.address
        )
      ]);
    }

    // Check streak information
    const streakResult = chain.callReadOnlyFn(
      "zenpulse-sessions", 
      "get-user-streak", 
      [types.principal(user.address)],
      user.address
    );

    const streak = streakResult.result.expectSome();
    streak.expectTuple({
      "current-streak": types.uint(10),
    });
  },
});

Clarinet.test({
  name: "Sessions Contract: Weekly reward distribution",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get("wallet_1")!;
    
    // Log enough sessions to hit reward threshold
    for (let i = 0; i < 8; i++) {
      chain.mineBlock([
        Tx.contractCall(
          "zenpulse-sessions", 
          "log-meditation-session", 
          [
            types.uint(30),           // duration
            types.ascii("Mindfulness") // meditation type
          ],
          user.address
        )
      ]);
    }

    // Check rewards
    const rewardsResult = chain.callReadOnlyFn(
      "zenpulse-sessions", 
      "get-user-rewards", 
      [types.principal(user.address)],
      user.address
    );

    const rewards = rewardsResult.result.expectSome();
    rewards.expectTuple({
      "total-tokens": types.uint(10), // WEEKLY_REWARD_AMOUNT
    });
  },
});