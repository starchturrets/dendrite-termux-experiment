# dendrite-termux-experiment
This is a WIP repo intended to document how I got a basic dendrite server running on an old android phone.

[GUIDE.md](https://github.com/starchturrets/dendrite-termux-experiment/blob/main/guide.md)

# Caveats

- Despite Dendrite being very performant, I would not advise joining large rooms such as `#matrix:matrix.org`. Based on my testing, it can somewhat handle being in a ~1000 user room. Anything larger than that is likely to be unusable.
- Keeping your phone plugged in 24/7 can cause battery swelling and be a fire hazard. Possible mitigations include removing the battery (not possible on newer phones unfortunately), or limiting the maximum charge (can be achieved via root applications sometimes, and some phones support it natively.) 
-  As fun as it is to tinker and self host on something that would otherwise be e-waste, you're probably not going to get too much security on an EOL phone, which is stuck on an older version of Android/Linux kernel.  
