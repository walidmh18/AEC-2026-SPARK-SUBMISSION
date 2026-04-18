import pandas as pd

# 1. Load your data
df = pd.read_excel("cleaned_2023_with_zones.xlsx")  # Adjust the filename as needed

# 2. Define the 'Earthquake Impact' function
def simulate_earthquake(row, epicenter_wilaya):
    # If the policy is in the hit zone, apply damage based on RPA
    if row['WILAYA'] == epicenter_wilaya:
        if row['ZONE_RPA'] == 'III':
            return row['CAPITAL_ASSURE'] * 0.70  # 70% Loss
        elif row['ZONE_RPA'] == 'IIb':
            return row['CAPITAL_ASSURE'] * 0.40  # 40% Loss
    return 0  # No loss if far away

# 3. Run the simulation for an Algiers earthquake
df['SIMULATED_LOSS'] = df.apply(lambda row: simulate_earthquake(row, 'ALGER'), axis=1)

total_impact = df['SIMULATED_LOSS'].sum()
print(f"Total Financial Impact: {total_impact} DZD")