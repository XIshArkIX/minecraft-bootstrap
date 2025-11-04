from typing import Any


class IntContextManager:
    def __init__(self, value: int):
        self.value = value

    def __enter__(self):
        return self.value

    def __exit__(self, exc_type: Any, exc_value: Any, traceback: Any):
        pass
