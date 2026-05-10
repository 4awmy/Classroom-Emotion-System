from anyascii import anyascii
name = "محمد علاء لطفى"
with open('test_out.txt', 'w', encoding='utf-8') as f:
    f.write(f"Original: {name}\n")
    f.write(f"AnyASCII: {anyascii(name)}\n")
