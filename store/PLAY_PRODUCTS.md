# Google Play products for Word Lantern

Every id below must exist in the Play Console (Monetize › Products › In-app products)
before the shop works in a Play build. Prices are set in the Console; the game shows
Google Play's localised price and falls back to the regional prices in
`game/autoload/store.gd` until Play answers.

| Product id | Type | What it gives | Suggested US price |
|---|---|---|---|
| `complete_pack` | One-time (non-consumable) | Everything: no banner ads, 3 free Sparks a day, all themes and lantern styles, plus 1,000 coins and 5 level keys (granted once) | $5.99 |
| `supporter_pack` | One-time | No banner ads, 3 free Sparks a day | $2.99 |
| `theme_pack` | One-time | 11 colour themes (1-hour trial from a video) | $1.99 |
| `style_pack` | One-time | 6 lantern styles (1-hour trial from a video) | $1.99 |
| `coins_300` | Consumable | 300 coins | $0.99 |
| `coins_1000` | Consumable | 1,000 coins | $1.99 |
| `coins_2500` | Consumable | 2,500 coins | $2.99 |
| `coins_6000` | Consumable | 6,000 coins | $5.99 |
| `keys_1` … `keys_10` | Consumable | 1–10 level keys (₹30 / $0.49 each, 10% off for 5+) | $0.49 × n |
| `tip_10` … `tip_1000` (steps of 10) | Consumable | A tip: nothing unlocked (priced in rupees) | ₹10 × n |

Consumables are consumed after granting, so they can be bought again. One-time packs
are acknowledged and restored on every launch and from **Restore purchases**.

## Ads (AdMob)

Set three repository secrets so CI builds use the real units (otherwise Google's test
units are used): `ADMOB_APP_ID`, `ADMOB_BANNER_ID` (anchored adaptive banner) and
`ADMOB_REWARDED_ID` (rewarded video). Banners show at the bottom of every screen
except for Supporters; rewarded videos only play when the player asks (a hint when
out of coins, free coins, a free level key, or a 1-hour pack trial).
