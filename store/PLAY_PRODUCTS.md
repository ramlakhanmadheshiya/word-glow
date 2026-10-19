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
| `coins_100` | Consumable | 100 coins | ₹29 / $0.49 |
| `coins_250` | Consumable | 250 coins | ₹69 / $0.89 |
| `coins_300` | Consumable | 300 coins | ₹79 / $0.99 |
| `coins_500` | Consumable | 500 coins | ₹119 / $1.49 |
| `coins_750` | Consumable | 750 coins | ₹139 / $1.79 |
| `coins_1000` | Consumable | 1,000 coins | ₹149 / $1.99 |
| `coins_1500` | Consumable | 1,500 coins | ₹199 / $2.49 |
| `coins_2000` | Consumable | 2,000 coins | ₹229 / $2.79 |
| `coins_2500` | Consumable | 2,500 coins | ₹249 / $2.99 |
| `coins_6000` | Consumable | 6,000 coins | ₹449 / $5.99 |
| `chapter_keys_1` … `chapter_keys_5` | Consumable | 1–5 chapter keys (₹99 / $1.29 each): each opens a locked chapter at its level 1 | ₹99 × n |
| `keys_1` … `keys_10` | Consumable | 1–10 level keys (₹30 / $0.49 each, 10% off for 5+) | $0.49 × n |
| `tip_10` … `tip_1000` (steps of 10) | Consumable | A tip: nothing unlocked (priced in rupees) | ₹10 × n |

Consumables are consumed after granting, so they can be bought again. One-time packs
are acknowledged and restored on every launch and from **Restore purchases**.

## Ads (AdMob)

Set three repository secrets so CI builds use the real units (otherwise Google's test
units are used): `ADMOB_APP_ID`, `ADMOB_BANNER_ID` (anchored adaptive banner) and
`ADMOB_REWARDED_ID` (rewarded video) and, optionally, `ADMOB_INTERSTITIAL_ID` (the short video after every fifth level; without it Google's test unit is used). Banners show at the bottom of every screen
except for Supporters; rewarded videos only play when the player asks (a hint when
out of coins, free coins, a free level or chapter key, or a 1-hour pack trial). A short interstitial video plays after every fifth cleared level (not for Supporters). The banner loads a fresh ad when the player changes screens, at most once every 30 seconds.
