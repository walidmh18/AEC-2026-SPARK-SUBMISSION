"""
Fill missing zone codes in year CSVs by fuzzy matching unmatched communes
against the zones_clean_prefixed.csv reference.
"""
import csv
import unicodedata
import re
from pathlib import Path
from difflib import SequenceMatcher, get_close_matches
from collections import defaultdict


def normalize_text(value: str) -> str:
    """Normalize text for robust commune matching."""
    value = value.strip().lower()
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = value.replace("'", " ")
    value = re.sub(r"[^a-z0-9\s]", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    return value


def extract_base_name(name: str) -> str:
    """Extract base commune name, removing wilaya references like 'CHERAGA ALGER' -> 'CHERAGA'"""
    parts = name.split()
    # If name has multiple parts, try to identify the main commune name
    # Usually the longer or first meaningful part
    return parts[0] if parts else name


def load_zone_reference(zones_csv: Path) -> tuple:
    """Load zones_clean_prefixed.csv and build efficient mappings for matching."""
    reference_by_norm = {}
    norm_to_original = {}
    
    with zones_csv.open('r', encoding='utf-8', newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            commune_name = row['commune_name'].strip()
            zone = row['zone'].strip()
            if commune_name and zone:
                norm_name = normalize_text(commune_name)
                # Store first occurrence (deduplicate by normalized name)
                if norm_name not in reference_by_norm:
                    reference_by_norm[norm_name] = {
                        'original': commune_name,
                        'zone': zone,
                        'wilaya_code': row['wilaya_code'],
                        'wilaya_name': row['wilaya_name']
                    }
                    norm_to_original[norm_name] = commune_name
    
    return reference_by_norm, norm_to_original


def find_best_match(unmatched_commune: str, reference_by_norm: dict, norm_to_original: dict, cutoff: float = 0.75) -> tuple:
    """Find best matching commune in reference using difflib for efficiency."""
    unmatched_norm = normalize_text(unmatched_commune)
    
    if not unmatched_norm:
        return (None, 0.0, None)
    
    # Try exact match first
    if unmatched_norm in reference_by_norm:
        ref_data = reference_by_norm[unmatched_norm]
        return (ref_data['zone'], 1.0, ref_data['original'])
    
    # Use get_close_matches for efficient fuzzy matching
    all_normalized = list(norm_to_original.keys())
    matches = get_close_matches(unmatched_norm, all_normalized, n=1, cutoff=cutoff)
    
    if matches:
        matched_norm = matches[0]
        ref_data = reference_by_norm[matched_norm]
        # Calculate actual score
        matcher = SequenceMatcher(None, unmatched_norm, matched_norm)
        score = matcher.ratio()
        return (ref_data['zone'], score, ref_data['original'])
    
    return (None, 0.0, None)


def process_year_csv(year: int, reference_by_norm: dict, norm_to_original: dict, output_prefix: str = "enhanced_") -> dict:
    """
    Process year CSV, find unmatched rows, fill zones using fuzzy matching.
    Returns statistics about matches found.
    """
    input_path = Path(f"cleaned_{year}_with_zones.csv")
    output_path = Path(f"{output_prefix}{year}_with_zones.csv")
    
    matched_count = 0
    unmatched_count = 0
    filled_count = 0
    filled_details = defaultdict(list)
    
    rows_with_zones = []
    
    with input_path.open('r', encoding='utf-8', newline='') as infile:
        reader = csv.DictReader(infile)
        fieldnames = reader.fieldnames
        
        for row in reader:
            zone = row.get('zone', '').strip()
            
            if zone:  # Already has zone
                matched_count += 1
                rows_with_zones.append(row)
            else:  # Missing zone
                unmatched_count += 1
                commune_name = row.get('COMMUNE_NAME', '').strip()
                
                if commune_name:
                    # Try to find best match
                    found_zone, score, matched_name = find_best_match(commune_name, reference_by_norm, norm_to_original, cutoff=0.75)
                    
                    if found_zone:
                        row['zone'] = found_zone
                        filled_count += 1
                        filled_details[found_zone].append({
                            'original': commune_name,
                            'matched': matched_name,
                            'score': f"{score:.2f}"
                        })
                
                rows_with_zones.append(row)
    
    # Write enhanced output
    with output_path.open('w', encoding='utf-8', newline='') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows_with_zones)
    
    # Calculate final coverage
    final_with_zone = sum(1 for row in rows_with_zones if row.get('zone', '').strip())
    total = len(rows_with_zones)
    
    return {
        'year': year,
        'total': total,
        'matched_initial': matched_count,
        'unmatched_initial': unmatched_count,
        'filled': filled_count,
        'final_with_zone': final_with_zone,
        'improve_pct': (filled_count / unmatched_count * 100) if unmatched_count > 0 else 0,
        'final_coverage': (final_with_zone / total * 100) if total > 0 else 0,
        'filled_details': filled_details
    }


def main():
    zones_csv = Path("zones_clean_prefixed.csv")
    
    print("Loading zone reference from zones_clean_prefixed.csv...")
    reference_by_norm, norm_to_original = load_zone_reference(zones_csv)
    print(f"Loaded {len(reference_by_norm)} unique normalized communes with zones\n")
    
    results = []
    for year in [2023, 2024, 2025]:
        print(f"Processing {year}...")
        result = process_year_csv(year, reference_by_norm, norm_to_original)
        results.append(result)
        
        print(f"  Total rows: {result['total']}")
        print(f"  Initially matched: {result['matched_initial']}")
        print(f"  Initially unmatched: {result['unmatched_initial']}")
        print(f"  Filled by fuzzy match: {result['filled']} ({result['improve_pct']:.1f}% of unmatched)")
        print(f"  Final coverage: {result['final_with_zone']}/{result['total']} ({result['final_coverage']:.1f}%)")
        print(f"  Wrote: enhanced_{year}_with_zones.csv\n")
    
    # Summary
    print("="*60)
    print("SUMMARY")
    print("="*60)
    for result in results:
        year = result['year']
        print(f"\n{year}:")
        print(f"  Coverage improvement: {result['matched_initial']} → {result['final_with_zone']} rows")
        print(f"  Additional zones filled: {result['filled']}")
        print(f"  Final coverage: {result['final_coverage']:.1f}%")


if __name__ == "__main__":
    main()
