from pathlib import Path
p=Path('scripts/presentation/RiverArtTrial.gd')
s=p.read_text(encoding='utf-8')
a=s.index('func _ready()',s.index('func _verify()'))
b=s.index('func _read(path:',a)
p.write_text(s[:a]+s[b:],encoding='utf-8')
