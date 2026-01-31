# Sample Python file for testing code parsing
import os
import sys
from pathlib import Path
from typing import List, Optional

CONSTANT = 42
CONFIG_PATH = "/etc/config"
debug_mode = True


class MyClass:
    class_var = "class level"

    def __init__(self):
        self.instance_var = "instance"

    def method(self):
        return self.instance_var


def simple_function():
    return "hello"


def function_with_args(name, count=1):
    return name * count


def function_with_print():
    print("output")
    return True


async def async_function():
    return await some_async_call()


# A comment
another_global = {"key": "value"}
