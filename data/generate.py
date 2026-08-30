#!/usr/bin/env python3
"""Synthetic data generator for a craft meat-production business.

Produces three years of reproducible, domain-realistic data as CSV files that
the ETL layer loads into PostgreSQL. Nothing here is scraped or copied from a
real company — every distribution below is documented so the data can be
trusted as *representative* rather than random noise:

  * Seasonality — sales peak in December (holidays) and rise in summer for
    grill sausages; January is the trough. See SEASON.
  * Production yield — output is 92–98% of planned on a good batch, with ~6%
    of batches running 78–88% (bad runs). See make_batches.
  * Write-offs (spoilage) — scale with production volume and *inversely* with
    shelf life: fresh pate/grill lose 4–8%/month, dry-cured salami <1.5%.
  * Prices — a base price per category, raised ~12%/year (inflation), stored
    as a valid_from/valid_to history.
  * Channel mix — 55% shops, 30% HoReCa, 15% distributors; order size and
    frequency differ sharply by channel.

Run:  python data/generate.py [output_dir]   (default: data/csv)
"""
from __future__ import annotations

import csv
import os
import random
import sys
from datetime import date, timedelta

from faker import Faker

SEED = 42
random.seed(SEED)
fake = Faker("uk_UA")
Faker.seed(SEED)

END = date(2026, 8, 31)
START = date(2023, 9, 1)          # ~3 years
MONTHS = []
_y, _m = START.year, START.month
while (_y, _m) <= (END.year, END.month):
    MONTHS.append(date(_y, _m, 1))
    _m += 1
    if _m == 13:
        _m = 1
        _y += 1

# month number -> demand multiplier (seasonality)
SEASON = {1: 0.70, 2: 0.85, 3: 0.95, 4: 1.00, 5: 1.05, 6: 1.10,
          7: 1.10, 8: 1.05, 9: 1.00, 10: 1.05, 11: 1.20, 12: 1.55}

# ---------------------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------------------
INGREDIENTS = [
    # name, unit, cost_per_kg (UAH)
    ("Свинина (лопатка)", "kg", 180),
    ("Свинина (грудинка)", "kg", 160),
    ("Яловичина (тримінг)", "kg", 220),
    ("Шпик/сало", "kg", 90),
    ("Курятина (філе)", "kg", 120),
    ("Сіль кухонна", "kg", 15),
    ("Сіль нітритна", "kg", 40),
    ("Перець чорний", "kg", 350),
    ("Часник", "kg", 120),
    ("Паприка", "kg", 200),
    ("Коріандр", "kg", 180),
    ("Цукор", "kg", 30),
    ("Оболонка натуральна", "kg", 250),
    ("Оболонка колагенова", "kg", 180),
    ("Вода питна", "kg", 1),
    ("Фосфати", "kg", 120),
    ("Аскорбат натрію", "kg", 300),
    ("Стартові культури", "kg", 900),
    ("Дим коптильний", "kg", 50),
    ("Коньяк", "kg", 600),
]

# category: (base_price_per_kg, shelf_life_days, spoil_rate_month, n_products)
CATEGORIES = {
    "Варені ковбаси":        (220, 30, 0.030, 8),
    "Напівкопчені ковбаси":  (320, 45, 0.020, 8),
    "Сирокопчені/Салямі":    (560, 120, 0.010, 7),
    "Делікатеси":            (1150, 180, 0.008, 4),
    "Шинка":                 (450, 30, 0.030, 6),
    "Копченості/Бекон":      (500, 40, 0.022, 6),
    "Ковбаски/Гриль":        (300, 14, 0.060, 7),
    "Паштети":               (270, 12, 0.070, 5),
}

# Which ingredients dominate a category's recipe (bill of materials).
CATEGORY_BOM = {
    "Варені ковбаси":       [("Свинина (лопатка)", 0.55), ("Шпик/сало", 0.20), ("Вода питна", 0.15), ("Сіль нітритна", 0.02), ("Фосфати", 0.01), ("Перець чорний", 0.01), ("Оболонка колагенова", 0.02)],
    "Напівкопчені ковбаси": [("Свинина (лопатка)", 0.45), ("Яловичина (тримінг)", 0.25), ("Шпик/сало", 0.20), ("Сіль нітритна", 0.02), ("Часник", 0.02), ("Перець чорний", 0.01), ("Оболонка натуральна", 0.03)],
    "Сирокопчені/Салямі":   [("Свинина (лопатка)", 0.50), ("Яловичина (тримінг)", 0.30), ("Шпик/сало", 0.15), ("Сіль нітритна", 0.02), ("Стартові культури", 0.005), ("Перець чорний", 0.01), ("Оболонка натуральна", 0.02)],
    "Делікатеси":           [("Свинина (лопатка)", 0.80), ("Сіль нітритна", 0.03), ("Перець чорний", 0.01), ("Коньяк", 0.02), ("Часник", 0.01)],
    "Шинка":                [("Свинина (лопатка)", 0.85), ("Вода питна", 0.08), ("Сіль нітритна", 0.02), ("Фосфати", 0.01), ("Аскорбат натрію", 0.005)],
    "Копченості/Бекон":     [("Свинина (грудинка)", 0.90), ("Сіль нітритна", 0.03), ("Дим коптильний", 0.01), ("Перець чорний", 0.01)],
    "Ковбаски/Гриль":       [("Свинина (лопатка)", 0.50), ("Курятина (філе)", 0.20), ("Шпик/сало", 0.15), ("Паприка", 0.02), ("Часник", 0.02), ("Оболонка натуральна", 0.05)],
    "Паштети":              [("Свинина (грудинка)", 0.55), ("Курятина (філе)", 0.25), ("Вода питна", 0.12), ("Сіль кухонна", 0.02), ("Перець чорний", 0.01)],
}

REGIONS = ["Київ", "Львів", "Одеса", "Харків", "Дніпро", "Вінниця",
           "Полтава", "Івано-Франківськ", "Тернопіль", "Житомир"]


def price_schedule(base: float, launch: date) -> list[tuple[date, date | None, float]]:
    """Yearly price steps (~12%/yr) from launch to END."""
    rows = []
    p = base * random.uniform(0.9, 1.1)
    year_start = date(launch.year, 1, 1)
    steps = []
    y = launch.year
    while y <= END.year:
        steps.append(date(y, 1, 1))
        y += 1
    steps[0] = launch  # first validity begins at launch
    for i, vf in enumerate(steps):
        vt = (steps[i + 1] - timedelta(days=1)) if i + 1 < len(steps) else None
        rows.append((vf, vt, round(p, 2)))
        p *= random.uniform(1.08, 1.16)
    return rows


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "csv")
    os.makedirs(out, exist_ok=True)

    def writer(name, header):
        f = open(os.path.join(out, name), "w", newline="", encoding="utf-8")
        w = csv.writer(f)
        w.writerow(header)
        return f, w

    # --- ingredients ---
    ing_id = {}
    f, w = writer("ingredients.csv", ["id", "name", "unit", "cost_per_unit"])
    for i, (name, unit, cost) in enumerate(INGREDIENTS, 1):
        ing_id[name] = i
        w.writerow([i, name, unit, cost])
    f.close()

    # --- products, bom, prices ---
    fp, wp = writer("products.csv", ["id", "sku", "name", "category", "shelf_life_days", "launch_date"])
    fb, wb = writer("bom.csv", ["id", "product_id", "ingredient_id", "qty_per_kg"])
    fpr, wpr = writer("prices.csv", ["id", "product_id", "price", "valid_from", "valid_to"])
    products = []          # (id, category, base_price, popularity, schedule)
    pid = 0
    bom_id = 0
    price_id = 0
    cat_codes = {c: f"C{idx+1}" for idx, c in enumerate(CATEGORIES)}
    for cat, (base, shelf, spoil, n) in CATEGORIES.items():
        for k in range(n):
            pid += 1
            sku = f"{cat_codes[cat]}-{k+1:02d}"
            name = f"{cat} №{k+1}"
            # products launch mostly before START, some later
            launch = START - timedelta(days=random.randint(0, 400))
            if random.random() < 0.12:  # a few products launched mid-history
                launch = START + timedelta(days=random.randint(60, 600))
            wp.writerow([pid, sku, name, cat, shelf, launch.isoformat()])
            for iname, qty in CATEGORY_BOM[cat]:
                bom_id += 1
                jitter = qty * random.uniform(0.92, 1.08)
                wb.writerow([bom_id, pid, ing_id[iname], round(jitter, 4)])
            sched = price_schedule(base, max(launch, date(launch.year, 1, 1)))
            for vf, vt, price in sched:
                price_id += 1
                wpr.writerow([price_id, pid, price, vf.isoformat(),
                              vt.isoformat() if vt else ""])
            popularity = random.uniform(0.5, 1.5)
            products.append({"id": pid, "cat": cat, "shelf": shelf,
                             "spoil": spoil, "base": base, "pop": popularity,
                             "launch": launch, "sched": sched})
    fp.close(); fb.close(); fpr.close()

    def price_at(prod, d: date) -> float:
        chosen = prod["sched"][0][2]
        for vf, vt, price in prod["sched"]:
            if vf <= d:
                chosen = price
        return chosen

    # --- clients ---
    fc, wc = writer("clients.csv", ["id", "name", "channel", "region", "since"])
    clients = []
    N_CLIENTS = 300
    for cid in range(1, N_CLIENTS + 1):
        r = random.random()
        if r < 0.55:
            channel, opm, size = "shop", 1.5, random.uniform(0.6, 1.4)
        elif r < 0.85:
            channel, opm, size = "horeca", 3.0, random.uniform(0.7, 1.5)
        else:
            channel, opm, size = "distributor", 6.0, random.uniform(0.8, 2.0)
        since = START - timedelta(days=random.randint(0, 700))
        if random.random() < 0.25:  # a quarter acquired during the period
            since = START + timedelta(days=random.randint(30, 900))
        # ~35% of clients churn (stop ordering) at some point → realistic
        # recency spread and declining cohort retention.
        if random.random() < 0.35:
            until = min(END, since + timedelta(days=random.randint(120, 720)))
        else:
            until = END
        name = fake.company()
        wc.writerow([cid, name, channel, REGIONS[random.randrange(len(REGIONS))],
                     since.isoformat()])
        clients.append({"id": cid, "channel": channel, "opm": opm * size,
                        "size": size, "since": since, "until": until})
    fc.close()

    # --- orders + order_items + shipments ---
    fo, wo = writer("orders.csv", ["id", "client_id", "order_date"])
    fi, wi = writer("order_items.csv", ["id", "order_id", "product_id", "qty_kg", "unit_price"])
    fs, ws = writer("shipments.csv", ["id", "order_id", "shipped_date", "delivered_date", "status"])
    order_id = 0
    item_id = 0
    ship_id = 0
    sold = {}                 # (product_id, month_start) -> kg sold, drives production
    active = [p for p in products]
    for mstart in MONTHS:
        season = SEASON[mstart.month]
        # days in month
        if mstart.month == 12:
            nextm = date(mstart.year + 1, 1, 1)
        else:
            nextm = date(mstart.year, mstart.month + 1, 1)
        ndays = (nextm - mstart).days
        # product weights for this month (grill boosted in summer)
        weights = []
        for p in active:
            wgt = p["pop"]
            if p["cat"] == "Ковбаски/Гриль" and mstart.month in (5, 6, 7, 8):
                wgt *= 1.8
            if p["cat"] == "Делікатеси" and mstart.month in (11, 12):
                wgt *= 1.5
            weights.append(wgt)
        for cl in clients:
            if cl["since"] > nextm or cl["until"] < mstart:
                continue
            base_n = cl["opm"] * season
            n_orders = max(0, round(random.gauss(base_n, base_n * 0.35)))
            for _ in range(n_orders):
                d = mstart + timedelta(days=random.randrange(ndays))
                if d < cl["since"] or d > cl["until"] or d > END:
                    continue
                order_id += 1
                wo.writerow([order_id, cl["id"], d.isoformat()])
                # lines
                if cl["channel"] == "shop":
                    nlines = random.randint(1, 3); qlo, qhi = 1, 6
                elif cl["channel"] == "horeca":
                    nlines = random.randint(2, 5); qlo, qhi = 3, 15
                else:
                    nlines = random.randint(2, 6); qlo, qhi = 10, 40
                chosen = set()
                picks = random.choices(active, weights=weights, k=nlines)
                mkey = date(d.year, d.month, 1)
                for p in picks:
                    if p["id"] in chosen or p["launch"] > d:
                        continue
                    chosen.add(p["id"])
                    qty = round(random.uniform(qlo, qhi), 2)
                    item_id += 1
                    wi.writerow([item_id, order_id, p["id"], qty, price_at(p, d)])
                    sold[(p["id"], mkey)] = sold.get((p["id"], mkey), 0) + qty
                # shipment
                ship_id += 1
                shipped = d + timedelta(days=random.randint(0, 2))
                delivered = shipped + timedelta(days=random.randint(1, 3))
                status = "delivered" if delivered <= END else "in_transit"
                ws.writerow([ship_id, order_id, shipped.isoformat(),
                             delivered.isoformat() if status == "delivered" else "",
                             status])
    fo.close(); fi.close(); fs.close()

    # --- production_batches + write_offs ---------------------------------------
    # Production is DEMAND-DRIVEN so the dataset stays internally consistent:
    # a product is made ~15% above what it sells each month, plus an opening
    # stock, so cumulative production stays ahead of sales and the inventory /
    # turnover analysis is meaningful. Write-offs scale with monthly output.
    fpb, wpb = writer("production_batches.csv", ["id", "product_id", "batch_date", "planned_kg", "actual_kg"])
    fw, ww = writer("write_offs.csv", ["id", "product_id", "writeoff_date", "qty_kg", "reason"])
    batch_id = 0
    wo_id = 0
    REASONS = ["термін придатності", "порушення температури", "брак пакування", "невідповідність якості"]

    def next_month(m: date) -> date:
        return date(m.year + 1, 1, 1) if m.month == 12 else date(m.year, m.month + 1, 1)

    def month_weeks(m: date) -> list[date]:
        nm = next_month(m)
        wks, d = [], m
        while d < nm:
            wks.append(d)
            d += timedelta(days=7)
        return wks

    def a_yield() -> float:
        if random.random() < 0.06:
            return random.uniform(0.78, 0.88)          # bad batch
        return min(1.0, random.gauss(0.95, 0.03))

    for p in products:
        active_months = [m for m in MONTHS if p["launch"] < next_month(m)]
        demands = [sold.get((p["id"], m), 0.0) for m in active_months]
        avg_dem = (sum(demands) / len(demands)) if demands else 0.0
        if avg_dem <= 0:
            continue
        open_date = max(p["launch"], START)
        # opening stock ~ half a month of average demand
        opening = avg_dem * 0.5
        batch_id += 1
        wpb.writerow([batch_id, p["id"], open_date.isoformat(),
                      round(opening, 2), round(opening * a_yield(), 2)])
        for m in active_months:
            dem = sold.get((p["id"], m), 0.0)
            target = max(dem * 1.15, avg_dem * 0.15)   # ~15% over demand, min floor
            wks = [w for w in month_weeks(m) if open_date <= w <= END]
            if not wks:
                continue
            per_week = target / len(wks)
            month_actual = 0.0
            for w in wks:
                planned = max(5, random.gauss(per_week, per_week * 0.15))
                actual = planned * a_yield()
                month_actual += actual
                batch_id += 1
                wpb.writerow([batch_id, p["id"], w.isoformat(),
                              round(planned, 2), round(actual, 2)])
            rate = p["spoil"] * random.uniform(0.6, 1.5)
            qty = month_actual * rate
            if qty >= 1:
                wo_id += 1
                day = m + timedelta(days=random.randrange(28))
                ww.writerow([wo_id, p["id"], day.isoformat(), round(qty, 2),
                             REASONS[random.randrange(len(REASONS))]])
    fpb.close(); fw.close()

    print(f"Generated CSVs in {out}")
    print(f"  products={pid}  clients={N_CLIENTS}  orders={order_id}  "
          f"order_items={item_id}  batches={batch_id}  write_offs={wo_id}")


if __name__ == "__main__":
    main()
