import pymupdf
import sys

def hex_to_rgb(color_int):
    # PyMuPDF color is usually an integer representing RGB (or sometimes BGR depending on color space, but usually RGB int)
    # Actually, text span color in PyMuPDF is an sRGB integer: (R << 16) + (G << 8) + B
    r = ((color_int >> 16) & 255) / 255.0
    g = ((color_int >> 8) & 255) / 255.0
    b = (color_int & 255) / 255.0
    return (r, g, b)

def replace_in_pdf(input_pdf, output_pdf, old_text, new_text):
    doc = pymupdf.open(input_pdf)
    
    for page in doc:
        instances = page.search_for(old_text)
        if not instances:
            continue
            
        text_dict = page.get_text("dict")
        
        for inst in instances:
            # Find matching span for font size and color
            matched_size = 11.0
            matched_color = (0, 0, 0)
            
            for block in text_dict.get("blocks", []):
                if "lines" not in block:
                    continue
                for line in block["lines"]:
                    for span in line["spans"]:
                        # check if the inst rect intersects with the span bbox
                        span_rect = pymupdf.Rect(span["bbox"])
                        if inst.intersects(span_rect):
                            matched_size = span["size"]
                            matched_color = hex_to_rgb(span["color"])
                            break
                            
            # Redact the old text
            page.add_redact_annot(inst, fill=(1, 1, 1))
            page.apply_redactions()
            
            # Insert the new text at the bottom-left of the bounding box
            # Adjust baseline
            baseline_y = inst.y1 - (inst.y1 - inst.y0) * 0.2
            point = pymupdf.Point(inst.x0, baseline_y)
            page.insert_text(point, new_text, fontsize=matched_size, fontname="helv", color=matched_color)
            print(f"Replaced at {inst} on page {page.number} with size {matched_size}")
            
    doc.save(output_pdf)

if __name__ == "__main__":
    replace_in_pdf(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
