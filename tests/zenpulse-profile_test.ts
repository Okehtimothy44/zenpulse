import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.2/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Profile Contract: User can create a profile with valid inputs",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get("wallet_1")!;
    const block = chain.mineBlock([
      Tx.contractCall(
        "zenpulse-profile", 
        "create-or-update-profile", 
        [
          types.uint(30),         // total-minutes
          types.uint(7),           // relaxation-level
          types.ascii("Jazz"),     // music-style
          types.ascii("Calm"),     // mood
          types.ascii("Zen")       // breathing-technique
        ],
        user.address
      )
    ]);

    block.receipts[0].result.expectOk().expectBool(true);

    // Verify profile was created
    const profileResult = chain.callReadOnlyFn(
      "zenpulse-profile", 
      "get-user-profile", 
      [types.principal(user.address)],
      user.address
    );
    
    const profile = profileResult.result.expectSome();
    profile.expectTuple({
      "total-meditation-minutes": types.uint(30),
      "relaxation-level": types.uint(7),
      "music-style": types.ascii("Jazz"),
      "mood-history": types.list([types.ascii("Calm")]),
      "breathing-technique": types.ascii("Zen")
    });
  },
});

Clarinet.test({
  name: "Profile Contract: Reject profile creation with invalid inputs",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get("wallet_1")!;
    const invalidTests = [
      {
        name: "Invalid relaxation level (0)",
        args: [types.uint(30), types.uint(0), types.ascii("Jazz"), types.ascii("Calm"), types.ascii("Zen")],
        expectedError: 400
      },
      {
        name: "Invalid relaxation level (11)",
        args: [types.uint(30), types.uint(11), types.ascii("Jazz"), types.ascii("Calm"), types.ascii("Zen")],
        expectedError: 400
      },
      {
        name: "Empty music style",
        args: [types.uint(30), types.uint(7), types.ascii(""), types.ascii("Calm"), types.ascii("Zen")],
        expectedError: 400
      }
    ];

    for (const test of invalidTests) {
      const block = chain.mineBlock([
        Tx.contractCall(
          "zenpulse-profile", 
          "create-or-update-profile", 
          test.args,
          user.address
        )
      ]);

      block.receipts[0].result.expectErr().expectUint(test.expectedError);
    }
  },
});

Clarinet.test({
  name: "Profile Contract: Update meditation minutes",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get("wallet_1")!;
    
    // First, create a profile
    chain.mineBlock([
      Tx.contractCall(
        "zenpulse-profile", 
        "create-or-update-profile", 
        [
          types.uint(30),
          types.uint(7),
          types.ascii("Jazz"),
          types.ascii("Calm"),
          types.ascii("Zen")
        ],
        user.address
      )
    ]);

    // Update meditation minutes
    const block = chain.mineBlock([
      Tx.contractCall(
        "zenpulse-profile", 
        "update-meditation-minutes", 
        [types.uint(20)],
        user.address
      )
    ]);

    block.receipts[0].result.expectOk().expectBool(true);

    // Verify minutes updated
    const totalMinutesResult = chain.callReadOnlyFn(
      "zenpulse-profile", 
      "get-total-meditation-minutes", 
      [types.principal(user.address)],
      user.address
    );

    totalMinutesResult.result.expectSome().expectUint(50);
  },
});

Clarinet.test({
  name: "Profile Contract: Mood history tracking",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get("wallet_1")!;
    
    // Add multiple moods to ensure history tracking
    const moods = [
      "Calm", "Relaxed", "Focused", "Serene", 
      "Peaceful", "Mindful", "Balanced", "Tranquil",
      "Centered", "Blissful", "Zen"
    ];

    for (let mood of moods) {
      const block = chain.mineBlock([
        Tx.contractCall(
          "zenpulse-profile", 
          "create-or-update-profile", 
          [
            types.uint(30),
            types.uint(7),
            types.ascii("Jazz"),
            types.ascii(mood),
            types.ascii("Zen")
          ],
          user.address
        )
      ]);

      block.receipts[0].result.expectOk().expectBool(true);
    }

    // Verify mood history is limited to 10 entries
    const profileResult = chain.callReadOnlyFn(
      "zenpulse-profile", 
      "get-user-profile", 
      [types.principal(user.address)],
      user.address
    );

    const profile = profileResult.result.expectSome();
    const moodHistory = profile.expectTuple()["mood-history"];
    
    // Check only last 10 moods are saved
    moodHistory.expectList(10);
    assertEquals(moodHistory.list.length, 10);
  },
});