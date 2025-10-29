import re
from typing import Optional


def extractServerJarUrl(content: str) -> Optional[str]:
    pattern = r"https://piston-data\.mojang\.com/v1/objects/[0-9a-f]+/server\.jar"
    match = re.search(pattern, content)
    if not match:
        return None
    return match.group(0)



