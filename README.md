# Orbital

Orbital is a Solidity project that allows users to create and manage secure vaults, known as "Funds", composed of various tokens such as WBTC, ETH, USDC, PAXG, and others. The user who creates the fund becomes the "Fund Manager" and can trade among the tokens to manage depositors' money. The depositors can withdraw their tokens at any time, while the Fund Manager can only trade tokens within the fund and cannot withdraw tokens they did not deposit themselves. 

## Fees

Protocol Fees are as follows. .

- Fees apply to all users of the fund, other than the Fund Creator (a.k.a. "Fund Manager" or "Fund Operator"). Fund Managers are exempt from all fees and the protocol is free to use.
- All Fees are collected at the time of withdrawal from the fund.
- "Owner Fee" is sent to the Protocol Wallet and is less than or equal to 1%.
- "Operator Fee" is kept in the Fund's Vault, but is credited to the Fund Manager's balance.
- "User Fee" is kept in the Fund's Vault, and is effectively distributed to all current users of the vault, in proportion to their share of the total. The Fund Manager is treated as a user like any other, so that the Fund Manager's total Fee is the sum of the Operator Fee and their share of the User Fees.
- All Fees are determined at the time of the Fund's creation and are unchangable afterward.
- The Total Fee (Operator Fee + User Fee + Protocol Fee) must be less than or equal to 20%.

## Autotrade feature

Every Vault can be set in either Manual Mode or Automated Mode, by the Fund Manager. When in Manual mode, the Fund Manger has control over the trading of the tokens. When in Automated mode, tokens are traded in accordance with a strategy set by the Fund Manager via the website's front end. The strategy is encrypted to prevent front-running and can only be viewed by the Fund Manager and by the Protocol.

### Disabling Vaults

The Fund Manager or the Protocol Owner can disable a vault a any time. This will prevent future deposits or trades, but will still allow withdrawals.

### License

MIT
