## Ruby 2.6.10

```
samuel@aiko ~/P/s/a/b/core (main)> ruby fiber-creation.rb
2.6.10
Fiber duration: 3.34us
Fiber duration: 2.57us
Fiber duration: 2.06us
Fiber duration: 2.23us
Fiber duration: 1.96us
Fiber duration: 2.13us
Fiber duration: 1.99us
Fiber duration: 2.13us
Fiber duration: 1.97us
Fiber duration: 1.98us
Average: 2.23us
   Best: 1.96us
samuel@aiko ~/P/s/a/b/core (main)> ruby thread-creation.rb
2.6.10
Thread duration: 47.01us
Thread duration: 44.85us
Thread duration: 50.91us
Thread duration: 45.06us
Thread duration: 47.04us
Thread duration: 48.75us
Thread duration: 52.04us
Thread duration: 54.62us
Thread duration: 48.35us
Thread duration: 50.79us
Average: 48.94us
   Best: 44.85us
```

## Ruby 2.7.7

```
samuel@aiko ~/P/s/a/b/core (main)> ruby fiber-creation.rb
2.7.7
Fiber duration: 0.93us
Fiber duration: 0.89us
Fiber duration: 0.81us
Fiber duration: 0.83us
Fiber duration: 0.82us
Fiber duration: 0.77us
Fiber duration: 0.73us
Fiber duration: 0.79us
Fiber duration: 0.88us
Fiber duration: 0.8us
Average: 0.83us
   Best: 0.73us
samuel@aiko ~/P/s/a/b/core (main)> ruby thread-creation.rb
2.7.7
Thread duration: 13.44us
Thread duration: 11.32us
Thread duration: 11.05us
Thread duration: 10.71us
Thread duration: 9.22us
Thread duration: 9.89us
Thread duration: 9.48us
Thread duration: 10.25us
Thread duration: 9.92us
Thread duration: 9.52us
Average: 10.48us
   Best: 9.22us
```

## Ruby 3.0.4

```
samuel@aiko ~/P/s/a/b/core (main)> ruby fiber-creation.rb
3.0.4
Fiber duration: 0.88us
Fiber duration: 0.85us
Fiber duration: 0.78us
Fiber duration: 0.76us
Fiber duration: 0.81us
Fiber duration: 0.71us
Fiber duration: 0.87us
Fiber duration: 0.89us
Fiber duration: 0.76us
Fiber duration: 0.96us
Average: 0.83us
   Best: 0.71us
samuel@aiko ~/P/s/a/b/core (main)> ruby thread-creation.rb
3.0.4
Thread duration: 13.72us
Thread duration: 10.92us
Thread duration: 9.97us
Thread duration: 9.44us
Thread duration: 9.28us
Thread duration: 9.38us
Thread duration: 9.31us
Thread duration: 9.45us
Thread duration: 9.4us
Thread duration: 9.39us
Average: 10.03us
   Best: 9.28us
```

## Ruby 3.1.3

```
samuel@aiko ~/P/s/a/b/core (main)> ruby fiber-creation.rb
3.1.3
Fiber duration: 0.94us
Fiber duration: 0.89us
Fiber duration: 0.86us
Fiber duration: 0.87us
Fiber duration: 0.71us
Fiber duration: 0.78us
Fiber duration: 0.79us
Fiber duration: 0.91us
Fiber duration: 0.75us
Fiber duration: 0.75us
Average: 0.82us
   Best: 0.71us
samuel@aiko ~/P/s/a/b/core (main)> ruby thread-creation.rb
3.1.3
Thread duration: 13.42us
Thread duration: 11.78us
Thread duration: 11.84us
Thread duration: 10.92us
Thread duration: 10.98us
Thread duration: 9.34us
Thread duration: 11.2us
Thread duration: 11.29us
Thread duration: 14.21us
Thread duration: 11.86us
Average: 11.68us
   Best: 9.34us
```

## Ruby 3.2.1

```
samuel@aiko ~/P/s/a/b/core (main)> ruby fiber-creation.rb
3.2.1
Fiber duration: 1.07us
Fiber duration: 0.91us
Fiber duration: 0.83us
Fiber duration: 0.86us
Fiber duration: 0.81us
Fiber duration: 0.83us
Fiber duration: 0.82us
Fiber duration: 0.83us
Fiber duration: 0.84us
Fiber duration: 0.81us
Average: 0.86us
   Best: 0.81us
samuel@aiko ~/P/s/a/b/core (main)> ruby thread-creation.rb
3.2.1
Thread duration: 13.3us
Thread duration: 11.71us
Thread duration: 13.17us
Thread duration: 10.61us
Thread duration: 8.94us
Thread duration: 11.99us
Thread duration: 12.63us
Thread duration: 12.04us
Thread duration: 10.63us
Thread duration: 12.73us
Average: 11.77us
   Best: 8.94us
```
