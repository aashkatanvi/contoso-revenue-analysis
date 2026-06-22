def artl_uplift(category_artl, current_online_artl, share_recovered_pct):
    return (category_artl - current_online_artl) * (share_recovered_pct / 100)

def new_online_artl(current_online_artl, uplift):
    return current_online_artl + uplift

current_online_artl = 189.14

categories = {
    "Home Appliances": 336.63,
    "Cameras & Camcorders": 330.05,
    "TV & Video": 409.12
}

scenarios = [1, 3, 5]

results = []

for category, category_artl in categories.items():

    for recovery_pct in scenarios:

        uplift = artl_uplift(
            category_artl,
            current_online_artl,
            recovery_pct
        )

        new_artl = new_online_artl(
            current_online_artl,
            uplift
        )

        results.append([
            category,
            recovery_pct,
            round(uplift, 2),
            round(new_artl, 2)
        ])

print(results)


import pandas as pd

df = pd.DataFrame(
    results,
    columns=[
        "Category",
        "Recovery %",
        "ARTL Uplift",
        "New Online ARTL"
    ]
)

print(df)

df.to_csv("artl_scenario_analysis.csv", index=False)

print("CSV saved successfully!")

