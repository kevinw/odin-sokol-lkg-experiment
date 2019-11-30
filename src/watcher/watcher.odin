package watcher

import "core:fmt"
import "core:sync"
import "core:thread"
import "core:strings"
import "core:mem"

import "core:sys/win32"

Change_Type :: enum {
    Modify,
    Add,
    Remove,
}

Change_Notification :: struct {
    change : Change_Type,
    asset_id : string,
    //catalog : ^Catalog,
}

@private _change_mutex : sync.Mutex;
@private _change_queue : [dynamic]Change_Notification;


// remove_unordered requires indices to be in order or it can fuck up big time
@private remove_ordered :: proc(array: ^[dynamic]$T, indices: ..int) {
    assert(array != nil && len(array^) != 0);
    a := cast(^mem.Raw_Dynamic_Array) array;
    for idx, i in indices {
        index := idx - i;
        if index < 0 || a.len <= 0 || a.len <= index do return;
        if index < a.len - 1 {
            mem.copy(&array[index], &array[index+1], size_of(T) * (a.len - index));
        }
        a.len -= 1;
    }
}

@private pop_front :: inline proc(array: ^[dynamic]$T) -> T {
    tmp := array[0];
    remove_ordered(array, 0);
    return tmp;
}


handle_changes :: proc() {
    //TODO(Hoej): Use try locks instead.
    sync.mutex_lock(&_change_mutex);
    qlen := len(_change_queue);
    sync.mutex_unlock(&_change_mutex);
    
    for qlen > 0 {
        sync.mutex_lock(&_change_mutex);
        noti := pop_front(&_change_queue);
        qlen -= 1;
        sync.mutex_unlock(&_change_mutex);
        
        //handle
        fmt.println(noti);
        /*
        asset := find(noti.catalog, noti.asset_id);
        switch a in asset.derived {
            case ^Shader : {
                _reload_shader(a, noti.catalog);
            }
        }
        */
    }
}

_setup_notification :: proc(path: string) {
    @static did_init := false;
    if !did_init {
        did_init = true;
        sync.mutex_init(&_change_mutex);
    }
    cstr := strings.clone_to_cstring(path); defer delete(cstr);
    dirh := win32.create_file_a(cstr, win32.FILE_GENERIC_READ, win32.FILE_SHARE_READ | win32.FILE_SHARE_DELETE | win32.FILE_SHARE_WRITE, nil, 
                                win32.OPEN_EXISTING, win32.FILE_FLAG_BACKUP_SEMANTICS, nil);
    if dirh == win32.INVALID_HANDLE {
        fmt.eprintln("Could not open directory at", path);
        return;
    }
    
    _payload :: struct {
        dir_handle: win32.Handle,
        //cat       : ^Catalog,
        buf       : rawptr,
        buf_len   : u32,
    };

    p := new(_payload);
    p.dir_handle = dirh;
    //p.cat = cat;
    BUF_SIZE := u32(4096);
    p.buf = mem.alloc(int(BUF_SIZE));
    p.buf_len = BUF_SIZE;

    remove_last_extension :: proc(str : string) -> string {
        last_dot := -1;
        for r, i in str {
            if r == '.' do last_dot = i;
        }
        
        return last_dot != -1 ? str[:last_dot] : str;
    }

    _proc :: proc(thread : ^thread.Thread) -> int {
        using p := cast(^_payload)thread.data;
        defer free(p);

        for {
            out : u32;
            ok := win32.read_directory_changes_w(dir_handle, buf, buf_len, false,
                                                  win32.FILE_NOTIFY_CHANGE_LAST_WRITE | win32.FILE_NOTIFY_CHANGE_FILE_NAME, 
                                                  &out, nil, nil);
            if ok {
                c := cast(^win32.File_Notify_Information)buf;
                for c != nil {
                    wlen := int(c.file_name_length) / size_of(u16);
                    wstr := &c.file_name[0];
                    req := win32.wide_char_to_multi_byte(win32.CP_UTF8, 0, 
                                            win32.Wstring(wstr), i32(wlen),
                                            nil, 0, 
                                            nil, nil);
                    asset_id := "N/A";
                    if req != 0 {
                        buf := make([]byte, req);
                        ok := win32.wide_char_to_multi_byte(win32.CP_UTF8, 0, 
                                                      win32.Wstring(wstr), i32(wlen),
                                                      cstring(&buf[0]), i32(len(buf)), 
                                                      nil, nil);
                        assert(ok != 0);
                        str := string(buf[:]);
                        asset_id = remove_last_extension(str);
                    } 

                    switch c.action {
                        case win32.FILE_ACTION_ADDED:
                        case win32.FILE_ACTION_REMOVED:
                        case win32.FILE_ACTION_MODIFIED:
                            _push_change({
                                change=.Modify,
                                asset_id=asset_id,
                            });
                    }

                    if c.next_entry_offset == 0 {
                        c = nil;
                    } else {
                        c = cast(^win32.File_Notify_Information)(cast(uintptr)cast(^byte)c + cast(uintptr)c.next_entry_offset);
                    }
                }
            } else {
                fmt.eprintf("last win32 error: %d\n", win32.get_last_error());
                break;
            }
        }

        win32.close_handle(dir_handle);
        return 0;
    }


    thread_obj := thread.create(_proc);
    //cat._notify_thread = thread.create(_proc);
    thread_obj.data = p;
    thread.start(thread_obj);
}

_push_change :: proc(noti: Change_Notification) -> bool {
    sync.mutex_lock(&_change_mutex);
    already := false;
    for c in _change_queue {
        if c.asset_id == noti.asset_id &&
           c.change == noti.change {
            already = true;
            break;
        }
    }
        
    if !already do append(&_change_queue, noti);

    sync.mutex_unlock(&_change_mutex);
    return !already;
}

/*
foreign import "system:kernel32.lib"
@(default_calling_convention = "std")
foreign kernel32 {
	@(link_name="MsgWaitForMultipleObjects") msg_wait_for_multiple_objects :: proc(
        count: u32, handles: ^win32.Handle, wait_all: win32.Bool, milliseconds: u32, wake_mask: u32) -> u32 ---;
}
QS_ALLEVENTS :: 0x04BF;


Watcher :: struct {
    handle: win32.Handle
};

init :: proc(using watcher: ^Watcher, dir_to_watch: string)
{
    dir := strings.clone_to_cstring(dir_to_watch, context.temp_allocator);

    filter :: u32(win32.FILE_NOTIFY_CHANGE_LAST_WRITE);

    watch_subtree:win32.Bool : true;
    handle = win32.find_first_change_notification_a(dir, watch_subtree, filter);
    if handle == win32.INVALID_HANDLE {
        fmt.eprintln("error: FindFirstChangeNotification failed for ", dir_to_watch);
        return;
    }
}

update :: proc(using watcher: ^Watcher) {
    res := msg_wait_for_multiple_objects(1, &handle, false, 0, QS_ALLEVENTS);
    switch res {
        case win32.WAIT_OBJECT_0:
            if !win32.find_next_change_notification(handle) {
                fmt.eprintln("error in find_next_change_notification");
            }
        case win32.WAIT_OBJECT_0 + 1:
            // we have a message - peek and dispatch it
            msg: win32.Msg;
            for win32.peek_message_w(&msg, nil, 0, 0, win32.PM_REMOVE) {
                // TODO:  must handle WM_QUIT; see Raymond's blog for details
                win32.translate_message(&msg);
                win32.dispatch_message_w(&msg);
            }

        case win32.WAIT_TIMEOUT:
            // do nothing
        case:
            fmt.eprintln("unexpected value from msg_wait_for_multiple_objects:", res);
    }
}
*/

