[ 
  {
    name = "base",
    repo = "https://github.com/dfinity/motoko-base",
    version = "moc-0.8.2",
    dependencies = [] : List Text
  },
  {
    name = "mrr",
    repo = "https://github.com/research-ag/motoko-lib",
    version = "master",
    dependencies = [ "base" ]
  },
  {
    name = "wip",
    repo = "https://github.com/research-ag/motoko-wip",
    version = "master",
    dependencies = [ "base" ]
  }
]