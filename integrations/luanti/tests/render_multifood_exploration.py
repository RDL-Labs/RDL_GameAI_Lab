import gzip
import json
from pathlib import Path
from .render_landmark_exploration import render


if __name__=="__main__":
    import sys
    a=json.loads(gzip.decompress(Path(sys.argv[1]).read_bytes()))
    render(a,sys.argv[2],title="L13W / Five Food sites, unchanged exploration and learning",
           conclusion="Five fixed Food sites; same terrain, perception range and L13V exploration. Discovery and pickup are counted separately.")
