# TODO

- [x] Expose metadata via query API

- [ ] In-memory JSONDatabase redesign
  - [x] Use multiple normalized stores per entity at the root and model
        relations as links
  - [x] Back & circular references
  - [ ] Converter from PostgreSQL to JSONDatabase JSON format

- [ ] Create/Edit support for databases

- [ ] Add more combinators
  - [ ] Compare operators (=, !=, <, >, <=, >=)
  - [ ] Logical operators (&&, ||, !)
  - [ ] Filter
  - [ ] String interpolation
  - [ ] Numeric ops (+, -, *, /, mod?, div?)
  - [ ] String ops / interpolation
- [ ] Add conditionals to workflow language
- [ ] Choice eliminators
- [ ] Add locations to lexer/parser
- [ ] Improve error reporting to provide more context (location, contextual
      info)
- [ ] Add pretty-printer
- [ ] Allow editing workflow "live"
- [ ] Compilation into SQL
- [ ] Better query/workflow editing experience
