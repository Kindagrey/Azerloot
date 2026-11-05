import ctypes, os
S = ctypes.CDLL("/home/claude/work/StormLib/build/libstorm.so")
H = ctypes.c_void_p
S.SFileOpenArchive.argtypes=[ctypes.c_char_p, ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(H)]
S.SFileOpenArchive.restype=ctypes.c_bool
S.SFileOpenFileEx.argtypes=[H, ctypes.c_char_p, ctypes.c_uint, ctypes.POINTER(H)]
S.SFileOpenFileEx.restype=ctypes.c_bool
S.SFileGetFileSize.argtypes=[H, ctypes.POINTER(ctypes.c_uint)]
S.SFileGetFileSize.restype=ctypes.c_uint
S.SFileReadFile.argtypes=[H, ctypes.c_void_p, ctypes.c_uint, ctypes.POINTER(ctypes.c_uint), ctypes.c_void_p]
S.SFileReadFile.restype=ctypes.c_bool
S.SFileCloseFile.argtypes=[H]
S.SFileHasFile.argtypes=[H, ctypes.c_char_p]; S.SFileHasFile.restype=ctypes.c_bool
def open_(path):
    h=H()
    if not S.SFileOpenArchive(path.encode(), 0, 0x100, ctypes.byref(h)): raise Exception('open '+path)
    return h
def has(h, name): return S.SFileHasFile(h, name.encode())
def read(h, name):
    f=H()
    if not S.SFileOpenFileEx(h, name.encode(), 0, ctypes.byref(f)): return None
    hi=ctypes.c_uint(0); n=S.SFileGetFileSize(f, ctypes.byref(hi))
    buf=ctypes.create_string_buffer(n); got=ctypes.c_uint(0)
    S.SFileReadFile(f, buf, n, ctypes.byref(got), None); S.SFileCloseFile(f)
    return buf.raw[:got.value]
