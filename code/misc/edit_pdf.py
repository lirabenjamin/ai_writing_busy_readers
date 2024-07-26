from PyPDF2 import PdfReader, PdfWriter, Transformation

# Load the PDF file
input_pdf_path = './cheatsheet5.pdf'
output_pdf_path = './cheatsheet_edited.pdf'

reader = PdfReader(input_pdf_path)
writer = PdfWriter()

# Extract the necessary parts
page = reader.pages[0]

# Create new writer objects for the top and bottom parts
top_writer = PdfWriter()
bottom_writer = PdfWriter()

# Extract top part (coordinates manually adjusted)
top_writer.add_page(page)
top_writer.pages[0].mediabox.upper_right = (612, 792)
top_writer.pages[0].mediabox.lower_left = (0, 228)

# Extract bottom part (coordinates manually adjusted)
bottom_writer.add_page(page)
bottom_writer.pages[0].mediabox.upper_right = (612, 160)
bottom_writer.pages[0].mediabox.lower_left = (0, 0)

# Save the temporary top and bottom parts
top_part_path = 'top_part.pdf'
bottom_part_path = 'bottom_part.pdf'

with open(top_part_path, 'wb') as f:
    top_writer.write(f)

with open(bottom_part_path, 'wb') as f:
    bottom_writer.write(f)

# export to png on adobe acrobat. 

from PIL import Image

# Load the two images
top_image_path = './top_part.png'
bottom_image_path = './bottom_part.png'
output_image_path = './cheatsheet_merged.png'

top_image = Image.open(top_image_path)
bottom_image = Image.open(bottom_image_path)

# Calculate the combined height
combined_height = top_image.height + bottom_image.height
width = max(top_image.width, bottom_image.width)

# Create a new image with the combined height
merged_image = Image.new('RGB', (width, combined_height))

# Paste the top and bottom images into the merged image
merged_image.paste(top_image, (0, 0))
merged_image.paste(bottom_image, (0, top_image.height))

# Save the merged image
merged_image.save(output_image_path, 'PNG')

print(f"Merged image saved to: {output_image_path}")
