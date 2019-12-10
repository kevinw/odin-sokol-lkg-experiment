package main


@private SEED :: 1999;

@private HASH := [?]byte {
    208,34,231,213,32,248,233,56,161,78,24,140,71,48,140,254,245,255,247,247,40,
    185,248,251,245,28,124,204,204,76,36,1,107,28,234,163,202,224,245,128,167,204,
    9,92,217,54,239,174,173,102,193,189,190,121,100,108,167,44,43,77,180,204,8,81,
    70,223,11,38,24,254,210,210,177,32,81,195,243,125,8,169,112,32,97,53,195,13,
    203,9,47,104,125,117,114,124,165,203,181,235,193,206,70,180,174,0,167,181,41,
    164,30,116,127,198,245,146,87,224,149,206,57,4,192,210,65,210,129,240,178,105,
    228,108,245,148,140,40,35,195,38,58,65,207,215,253,65,85,208,76,62,3,237,55,89,
    232,50,217,64,244,157,199,121,252,90,17,212,203,149,152,140,187,234,177,73,174,
    193,100,192,143,97,53,145,135,19,103,13,90,135,151,199,91,239,247,33,39,145,
    101,120,99,3,186,86,99,41,237,203,111,79,220,135,158,42,30,154,120,67,87,167,
    135,176,183,191,253,115,184,21,233,58,129,233,142,39,128,211,118,137,139,255,
    114,20,218,113,154,27,127,246,250,1,8,198,250,209,92,222,173,21,88,102,219};

noise2 :: proc(x, y: int) -> int {
    yindex:int = (y + SEED) % 256;
    if yindex < 0 do yindex += 256;
    xindex:int = (cast(int)HASH[yindex] + x) % 256;
    if xindex < 0 do xindex += 256;
    return cast(int)HASH[xindex];
}

lin_inter :: proc(x, y, s: f32) -> f32 {
    return x + s * (y - x);
}

smooth_inter :: proc(x, y, s: f32) -> f32 {
    return lin_inter(x, y, s * s * (3-2*s));
}

noise2d :: proc(x, y: f32) -> f32 {
    x_int := cast(int)x;
    y_int := cast(int)y;
    x_frac:f32 = x - cast(f32)x_int;
    y_frac:f32 = y - cast(f32)y_int;
    s:int= noise2(x_int, y_int);
    t:int= noise2(x_int+1, y_int);
    u:int= noise2(x_int, y_int+1);
    v:int= noise2(x_int+1, y_int+1);
    low := smooth_inter(cast(f32)s, cast(f32)t, x_frac);
    high := smooth_inter(cast(f32)u, cast(f32)v, x_frac);
    return smooth_inter(low, high, y_frac);
}

perlin2d :: proc(x, y, freq: f32, depth: int) -> f32 {
    xa:f32  = x*freq;
    ya:f32  = y*freq;
    amp:f32 = 1.0;
    fin:f32 = 0;
    div:f32 = 0.0;

    for _ in 0..<depth {
        div += 256 * amp;
        fin += noise2d(xa, ya) * amp;
        amp /= 2;
        xa *= 2;
        ya *= 2;
    }

    return fin/div;
}

