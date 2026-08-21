from pathlib import Path

def get_package_share_directory(name: str) -> str:
    '''
    Caller wants the entire ROS toolchain just to locate itself; satisfy them with 1 line.
    '''
    return str((Path(__file__).parents[3] / 'thirdparty/rosidl' / name).resolve())
