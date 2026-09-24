import pymupdf
import sys

def inspect_pdf(input_pdf, search_text):
    doc = pymupdf.open(input_pdf)
    for page_num, page in enumerate(doc):
        text_instances = page.search_for(search_text)
        if not text_instances:
            continue
            
        print(f"Page {page_num + 1}: Found '{search_text}' at {text_instances}")
        
        # Get detailed text info
        text_dict = page.get_text("dict")
        for block in text_dict["blocks"]:
            if "lines" not in block:
                continue
            for line in block["lines"]:
                for span in line["spans"]:
                    if search_text.lower() in span["text"].lower():
                        print(f"Match found in span:")
                        print(f"  Text: {span['text']}")
                        print(f"  Font: {span['font']}")
                        print(f"  Size: {span['size']}")
                        print(f"  Color: {span['color']}")
                        print(f"  Bbox: {span['bbox']}")

if __name__ == "__main__":
    inspect_pdf(sys.argv[1], sys.argv[2])
