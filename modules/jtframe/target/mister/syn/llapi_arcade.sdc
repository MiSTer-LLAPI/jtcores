# Cut asynchronous input sampling only; the second stages remain timed.
set llapi_meta [get_registers -nowarn {*|u_llapi|buttons1_meta[*] *|u_llapi|buttons2_meta[*] *|u_llapi|valid1_meta *|u_llapi|valid2_meta *|u_llapi|rst50_meta *|u_llapi|osd50_meta *|u_llapi|u_port1|new_sync *|u_llapi|u_port2|new_sync}]
if {[get_collection_size $llapi_meta] > 0} {
    set_false_path -to $llapi_meta
}

# First sampling stages of the optional SNAC bridge only.
set serial_meta [get_registers -nowarn {*|u_serial|mode_meta[*] *|u_serial|pad_meta[*] *|u_serial|active_meta[*] *|u_serial|ready_meta *|u_serial|u_snac|input_meta[*]}]
if {[get_collection_size $serial_meta] > 0} {
    set_false_path -to $serial_meta
}
