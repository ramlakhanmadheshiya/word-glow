#!/usr/bin/env python3
"""The in-app products Word Glow sells, and a way to create them on Google Play.

  python3 store/play_products.py list                  # print every product and price
  python3 store/play_products.py csv > store/products.csv
  python3 store/play_products.py create KEY.json       # create them through the API

  python3 store/play_products.py create KEY.json tip_10   # just these ids

`create` uses the Google Play Developer API (monetization.onetimeproducts) with a
service account JSON key (Play Console > Users and permissions: invite the service
account with permission to manage the app's products). It needs:
  python3 -m pip install google-auth requests
Existing products are updated in place, so it is safe to run again.

Prices are set in Indian rupees; Play converts them for other countries, and
players always see their own currency. Titles never mention a currency.
The product IDs must match game/autoload/store.gd (copied from Single Shot's script).
"""
import csv
import json
import re
import sys

PACKAGE = "com.theramlakhan.wordglow"
CURRENCY = "INR"

# One-time packs (kept forever, restorable).
PACKS = [
    ("complete_pack", "Complete pack", "No banner ads, 3 free letter hints a day, every theme and glow style, 1,000 coins and 5 level keys.", 449),
    ("supporter_pack", "Supporter pack", "No banner ads or videos between levels, and 3 free letter hints every day.", 249),
    ("theme_pack", "Theme pack", "Eleven colour themes for the whole game, light and dark.", 149),
    ("style_pack", "Glow styles", "Six new looks for tiles and lit words.", 149),
]
# Coin bags: id, coins, name, rupees (match COIN_PACKS in store.gd).
COINS = [
    ("coins_100", 100, 29), ("coins_250", 250, 69), ("coins_300", 300, 79), ("coins_500", 500, 119),
    ("coins_750", 750, 139), ("coins_1000", 1000, 149), ("coins_1500", 1500, 199), ("coins_2000", 2000, 229),
    ("coins_2500", 2500, 249), ("coins_6000", 6000, 449),
]
CHAPTER_KEY_PRICE = 99  # per chapter key
CHAPTER_KEY_MAX = 5
KEY_PRICE = 30          # per level key
KEY_BULK = 5            # buying this many or more ...
KEY_DISCOUNT = 0.10     # ... takes 10% off
KEY_MAX = 10
TIP_MIN, TIP_MAX, TIP_STEP = 10, 10000, 10
TIP_BIG_FROM, TIP_BIG_STEP = 1000, 100  # steps of 100 above 1,000


def products():
    out = []
    for pid, title, desc, price in PACKS:
        out.append({"id": pid, "title": title, "description": desc, "price": price, "kind": "pack"})
    for pid, coins, price in COINS:
        out.append({"id": pid, "title": f"{coins:,} coins", "description": "Coins pay for letter hints and word hints.", "price": price, "kind": "consumable"})
    for n in range(1, CHAPTER_KEY_MAX + 1):
        out.append({
            "id": f"chapter_keys_{n}",
            "title": f"{n} chapter key" + ("s" if n > 1 else ""),
            "description": "Opens a locked chapter at its level 1." if n == 1 else f"{n} keys. Each opens a locked chapter at its level 1.",
            "price": n * CHAPTER_KEY_PRICE,
            "kind": "consumable",
        })
    for n in range(1, KEY_MAX + 1):
        price = n * KEY_PRICE * (1 - KEY_DISCOUNT if n >= KEY_BULK else 1)
        out.append({
            "id": f"keys_{n}",
            "title": f"{n} level key" + ("s" if n > 1 else ""),
            "description": "A key opens any locked level for good." if n == 1 else f"{n} keys. Each opens any locked level for good.",
            "price": round(price),
            "kind": "consumable",
        })
    tips = list(range(TIP_MIN, TIP_BIG_FROM + 1, TIP_STEP)) + list(range(TIP_BIG_FROM + TIP_BIG_STEP, TIP_MAX + 1, TIP_BIG_STEP))
    for r in tips:
        out.append({
            "id": f"tip_{r}",
            "title": "Tip jar",
            "description": "A thank-you to the developer. Opens nothing new.",
            "price": r,
            "kind": "consumable",
        })
    return out


def cmd_list():
    for p in products():
        print(f"{p['id']:16s} ₹{p['price']:<5d} {p['kind']:10s} {p['title']}")
    print(f"\n{len(products())} products")


def cmd_csv():
    w = csv.writer(sys.stdout)
    w.writerow(["product_id", "title", "description", "price_inr", "kind"])
    for p in products():
        w.writerow([p["id"], p["title"], p["description"], p["price"], p["kind"]])


IN_GST = 1.18  # Play's Indian prices include 18% GST; conversion takes a tax-free base.


def _money(cur, amount):
    units = int(amount)
    return {"currencyCode": cur, "units": str(units), "nanos": int(round((amount - units) * 1e9))}


def cmd_create(key_path, only=None):
    """Creates (or updates) every product as a one-time product with one active
    "buy" purchase option: ₹ price in India, Play's converted prices elsewhere."""
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession

    creds = service_account.Credentials.from_service_account_file(
        key_path, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    session = AuthorizedSession(creds)
    app = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
    made, failed = 0, 0
    for p in products():
        if only and p["id"] not in only:
            continue
        conv = session.post(f"{app}/pricing:convertRegionPrices",
                            json={"price": _money(CURRENCY, p["price"] / IN_GST)})
        if not conv.ok:
            print(f"FAILED {p['id']} (prices): {conv.status_code} {conv.text[:300]}")
            failed += 1
            continue
        c = conv.json()
        regions = []
        for code, rp in sorted(c.get("convertedRegionPrices", {}).items()):
            price = _money(CURRENCY, p["price"]) if code == "IN" else rp["price"]
            regions.append({"regionCode": code, "price": price, "availability": "AVAILABLE"})
        other = c.get("convertedOtherRegionsPrice", {})
        option = {
            "purchaseOptionId": "buy",
            "buyOption": {"legacyCompatible": True, "multiQuantityEnabled": False},
            "regionalPricingAndAvailabilityConfigs": regions,
        }
        if other:
            option["newRegionsConfig"] = {"usdPrice": other["usdPrice"], "eurPrice": other["eurPrice"], "availability": "AVAILABLE"}
        body = {
            "packageName": PACKAGE,
            "productId": p["id"],
            "listings": [{"languageCode": "en-US", "title": p["title"], "description": p["description"]}],
            "purchaseOptions": [option],
        }
        # Small tips fall under some countries' minimum price: Play names the
        # region and its range, so lift that region to the minimum and retry.
        for _ in range(60):
            r = session.patch(f"{app}/onetimeproducts/{p['id']}", json=body, params={
                "allowMissing": "true", "updateMask": "listings,purchaseOptions",
                "regionsVersion.version": c["regionVersion"]["version"],
                "latencyTolerance": "PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT"})
            m = None if r.ok else re.search(r"Price for (\w+) must be between \D*([\d.,]+)", r.text)
            if not m:
                break
            for reg in regions:
                if reg["regionCode"] == m.group(1):
                    reg["price"] = _money(reg["price"]["currencyCode"], float(m.group(2).replace(",", "")))
        if not r.ok:
            print(f"FAILED {p['id']}: {r.status_code} {r.text[:400]}")
            failed += 1
            continue
        act = session.post(f"{app}/oneTimeProducts/{p['id']}/purchaseOptions:batchUpdateStates", json={"requests": [
            {"activatePurchaseOptionRequest": {"packageName": PACKAGE, "productId": p["id"], "purchaseOptionId": "buy",
                                               "latencyTolerance": "PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT"}}]})
        if not act.ok:
            print(f"FAILED {p['id']} (activate): {act.status_code} {act.text[:300]}")
            failed += 1
            continue
        made += 1
        print(f"ok     {p['id']} ₹{p['price']}")
    print(f"\nDone: {made} ready, {failed} failed.")


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        cmd_list()
    elif sys.argv[1] == "csv":
        cmd_csv()
    elif sys.argv[1] == "create" and len(sys.argv) >= 3:
        cmd_create(sys.argv[2], set(sys.argv[3:]) or None)
    else:
        print(__doc__)
        sys.exit(1)
