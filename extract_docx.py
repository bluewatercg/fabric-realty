import zipfile
import xml.etree.ElementTree as ET
import sys

def get_docx_text(path):
    """
    Take the path of a docx file as argument, return the text in unicode.
    """
    document = zipfile.ZipFile(path)
    xml_content = document.read('word/document.xml')
    document.close()
    tree = ET.fromstring(xml_content)
    
    # Define namespaces to avoid getting {http://...} everywhere
    namespaces = {
        'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    }
    
    text = ""
    for t in tree.findall('.//w:t', namespaces):
        if t.text:
            text += t.text
    return text

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python extract_docx.py <file.docx>")
        sys.exit(1)
    print(get_docx_text(sys.argv[1]))
