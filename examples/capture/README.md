# Capture

## Falcon

```
% wrk -t 8 -c 32 http://localhost:9292/
Running 10s test @ http://localhost:9292/
  8 threads and 32 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   106.31ms   10.20ms 211.79ms   98.00%
    Req/Sec    37.94      5.43    40.00     84.24%
  3003 requests in 10.01s, 170.16KB read
Requests/sec:    299.98
Transfer/sec:     17.00KB
```

```
0.0s: Process 28065 start times:
    | #<struct Process::Tms utime=2.38, stime=0.0, cutime=0.0, cstime=0.2>
^C15.11s: strace -p 28065
    | ["sendto", {:"% time"=>57.34, :seconds=>0.595047, :"usecs/call"=>14, :calls=>39716, :errors=>32, :syscall=>"sendto"}]
    | ["recvfrom", {:"% time"=>42.58, :seconds=>0.441867, :"usecs/call"=>12, :calls=>36718, :errors=>70, :syscall=>"recvfrom"}]
    | ["read", {:"% time"=>0.07, :seconds=>0.000723, :"usecs/call"=>7, :calls=>98, :errors=>nil, :syscall=>"read"}]
    | ["write", {:"% time"=>0.01, :seconds=>0.000112, :"usecs/call"=>56, :calls=>2, :errors=>nil, :syscall=>"write"}]
    | [:total, {:"% time"=>100.0, :seconds=>1.037749, :"usecs/call"=>nil, :calls=>76534, :errors=>102, :syscall=>"total"}]
15.11s: Process 28065 end times:
    | #<struct Process::Tms utime=3.93, stime=0.0, cutime=0.0, cstime=0.2>
15.11s: Process Waiting: 1.0377s out of 1.55s
    | Wait percentage: 66.95%
```

## Puma

```
wrk -t 8 -c 32 http://localhost:9292/
Running 10s test @ http://localhost:9292/
  8 threads and 32 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   108.83ms    3.50ms 146.38ms   86.58%
    Req/Sec    34.43      6.70    40.00     92.68%
  1371 requests in 10.01s, 81.67KB read
Requests/sec:    136.94
Transfer/sec:      8.16KB
```

```
0.0s: Process 28448 start times:
    | #<struct Process::Tms utime=0.63, stime=0.0, cutime=0.0, cstime=0.2>
^C24.89s: strace -p 28448
    | ["recvfrom", {:"% time"=>64.65, :seconds=>0.595275, :"usecs/call"=>13, :calls=>44476, :errors=>27769, :syscall=>"recvfrom"}]
    | ["sendto", {:"% time"=>30.68, :seconds=>0.282467, :"usecs/call"=>18, :calls=>15288, :errors=>nil, :syscall=>"sendto"}]
    | ["write", {:"% time"=>4.66, :seconds=>0.042921, :"usecs/call"=>15, :calls=>2772, :errors=>nil, :syscall=>"write"}]
    | ["read", {:"% time"=>0.02, :seconds=>0.000157, :"usecs/call"=>8, :calls=>19, :errors=>1, :syscall=>"read"}]
    | [:total, {:"% time"=>100.0, :seconds=>0.92082, :"usecs/call"=>nil, :calls=>62555, :errors=>27770, :syscall=>"total"}]
24.89s: Process 28448 end times:
    | #<struct Process::Tms utime=3.19, stime=0.0, cutime=0.0, cstime=0.2>
24.89s: Process Waiting: 0.9208s out of 2.56s
    | Wait percentage: 35.97%
```
