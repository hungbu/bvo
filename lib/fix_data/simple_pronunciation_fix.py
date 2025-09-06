#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Simple Pronunciation Fixer
Fix pronunciation quotes from single to double quotes
"""

import re

def fix_pronunciation_quotes():
    """Fix pronunciation quotes in dictionary file"""
    
    input_path = r"input.txt"
    output_path = r"output.txt"
    
    print("🔧 Simple Pronunciation Quote Fixer")
    print(f"📁 Input: {input_path}")
    print(f"📁 Output: {output_path}")
    
    try:
        # Read input file
        with open(input_path, 'r', encoding='utf-8') as f:
            content = f.read()
        print(f"📊 Original size: {len(content):,} characters")
        
        # Count original issues (including raw strings and missing quotes)
        pattern1 = r"pronunciation:\s*r?'[^']*',"  # Normal case with closing quote
        pattern2 = r"pronunciation:\s*r?'[^',]*,"  # Missing closing quote
        
        normal_quotes = len(re.findall(pattern1, content))
        missing_quotes = len(re.findall(pattern2, content)) - normal_quotes  # Subtract overlap
        total_issues = normal_quotes + missing_quotes
        
        print(f"🔍 Found {normal_quotes} pronunciation fields with complete single quotes")
        print(f"🔍 Found {missing_quotes} pronunciation fields with missing closing quotes")
        print(f"🔍 Total issues: {total_issues}")
        
        # Fix 1: Replace complete single quotes with double quotes
        # Pattern: pronunciation: r'/something/',  ->  pronunciation: "/something/",
        # Pattern: pronunciation: '/something/',   ->  pronunciation: "/something/",
        def replace_complete_pronunciation(match):
            pronunciation_content = match.group(1)
            return f'pronunciation: "{pronunciation_content}",'
        
        # Fix 2: Replace missing closing quotes
        # Pattern: pronunciation: '/ˈɡrʌmpi/,  ->  pronunciation: "/ˈɡrʌmpi/",
        def replace_missing_quote_pronunciation(match):
            pronunciation_content = match.group(1)
            return f'pronunciation: "{pronunciation_content}",'
        
        # Apply fixes
        fixed_content = content
        
        # First fix: Complete quotes
        fixed_content = re.sub(r"pronunciation:\s*r?'([^']*)',", replace_complete_pronunciation, fixed_content)
        
        # Second fix: Missing closing quotes (be more careful with pattern)
        fixed_content = re.sub(r"pronunciation:\s*r?'([^',\n]*),", replace_missing_quote_pronunciation, fixed_content)
        
        # Count final results
        remaining_pattern1 = len(re.findall(pattern1, fixed_content))
        remaining_pattern2 = len(re.findall(pattern2, fixed_content)) - remaining_pattern1
        total_remaining = remaining_pattern1 + remaining_pattern2
        fixed_count = total_issues - total_remaining
        
        print(f"✅ Fixed {fixed_count} pronunciation quote issues")
        print(f"📊 Fixed size: {len(fixed_content):,} characters")
        
        # Write output file
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        
        print(f"✅ Output file created: {output_path}")
        
        # Verify the fix
        double_quotes_count = len(re.findall(r'pronunciation:\s*"[^"]*",', fixed_content))
        print(f"🔍 Verification: {double_quotes_count} pronunciation fields now use double quotes")
        
        # Create summary report
        report_path = r"E:\exwork\vnwebsite\bvo\pronunciation_fix_report.txt"
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write("=== Pronunciation Fix Report ===\n")
            f.write(f"Input file: {input_path}\n")
            f.write(f"Output file: {output_path}\n")
            f.write(f"Original size: {len(content):,} characters\n")
            f.write(f"Fixed size: {len(fixed_content):,} characters\n")
            f.write(f"Complete single quotes: {normal_quotes}\n")
            f.write(f"Missing closing quotes: {missing_quotes}\n")
            f.write(f"Total issues: {total_issues}\n")
            f.write(f"Fixed quotes: {fixed_count}\n")
            f.write(f"Remaining issues: {total_remaining}\n")
            f.write(f"Double quotes after fix: {double_quotes_count}\n")
            f.write("\nFixes applied:\n")
            f.write("1. Changed: pronunciation: '/ˈɑːnɪst/', \n")
            f.write("   To:      pronunciation: \"/ˈɑːnɪst/\", \n")
            f.write("2. Changed: pronunciation: '/ˈɡrʌmpi/, \n")
            f.write("   To:      pronunciation: \"/ˈɡrʌmpi/\", \n")
            f.write("\n✅ Ready to use!\n")
        
        print(f"📋 Report created: {report_path}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = fix_pronunciation_quotes()
    if success:
        print("\n🎉 SUCCESS: Pronunciation quotes fixed!")
        print("🚀 Next steps:")
        print("1. Copy dictionary_new_fix.dart to dictionary.dart")
        print("2. Run 'flutter run' to test the app")
    else:
        print("\n❌ FAILED: Could not fix pronunciation quotes")
