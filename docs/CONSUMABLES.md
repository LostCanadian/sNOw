# Consumable upgrades — future work

Do not implement these in the current iteration. A later workshop could let players spend upgrade points on **one-time use items** alongside permanent equipment ranks.

The first candidate is **coffee**: buy one dose, then activate it during a level for a temporary running-speed boost. Its price, strength, duration, carrying limit and exact activation control need playtesting. Buying a consumable should be an explicit choice against spending that point on permanent equipment; score remains a separate currency. No real-money purchase or permanent cross-campaign grind is proposed.

Before implementation, decide:

- Whether inventory is per campaign and whether unused doses carry between weeks.
- Whether retries restore the level-start inventory, as they restore other resources, and how that interacts with high-score attempts.
- Whether speed boosts can extend each other, replace each other or never stack. Repeated activation must not multiply speed without a cap.
- How effects and inventory survive boundary saves, and how pause/focus loss freezes their timers.
- How an optional item button fits the existing portrait controls without overlapping movement, fan or Surge.
- How consumed items and point spending are recorded for future score comparisons and build review.

Keep permanent boots/blower/battery upgrades and the rechargeable Surge unchanged until that separate consumable pass. Author a coffee asset and concise inspection/confirmation text at that time.

Keep a separate ledger for points spent on consumables: earned points = unspent points + permanent-equipment spend + consumable spend. Reset Kit must not refund already-consumed coffee. Any inventory-refund rule should be explicit and covered by persistence tests when this feature is implemented.
