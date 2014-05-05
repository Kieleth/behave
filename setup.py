from cx_Freeze import setup, Executable

# Dependencies are automatically detected, but it might need fine tuning.
#build_exe_options = {"packages": ["os"], "excludes": ["tkinter"]}

# GUI applications require a different base on Windows (the default is for a
# console application).

setup(  name = "behave",
        version = "0.2",
        description = "Behave, face detection to help you",
        options = {'build_exe':
                    {'includes': ['numpy'],
                        'include_files': ['cascades/', 'lib/']}},
        executables = [Executable("capturebasic.py", )])
