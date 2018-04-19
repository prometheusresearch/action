open! Jest
open! Expect
open! Expect.Operators
module Q = Query.Untyped.Syntax

let () =

  let expectParseQueryAndEq s exp =
    test s begin fun () ->
      let filebuf = Lexing.from_string s in
      try
        let res = Parser.start Lexer.read filebuf in
        match res with
        | ParserResult.Query q ->
          expect(q) |> toEqual(exp)
        | ParserResult.Workflow _ ->
          fail "expected query"
      with
      | Lexer.Error msg ->
        fail msg
      | Parser.Error ->
        fail "Syntax error"
    end
  in

  let expectParseOk s =
    test s begin fun () ->
      let filebuf = Lexing.from_string s in
      try
        let res = Parser.start Lexer.read filebuf in
        match res with
        | ParserResult.Query _ ->
          pass
        | ParserResult.Workflow _ ->
          pass
      with
      | Lexer.Error msg ->
        fail msg
      | Parser.Error ->
        fail "Syntax error"
    end
  in

  describe "Parsing" begin fun () ->
    expectParseOk "/";
    expectParseOk "/ ";
    expectParseOk " /";
    expectParseOk "\n/";
    expectParseOk "/\n";
    expectParseOk "/individual";
    expectParseOk "individual"; expectParseOk "individual.site"; expectParseOk "individual.site.title";
    expectParseOk "individual{}";
    expectParseOk "individual { site }";
    expectParseOk "individual { site, }";
    expectParseOk "individual { site: site, }";
    expectParseOk "individual { site: site, name, }";
    expectParseOk "individual { site, site.title, individualName: name }";
    expectParseOk "individual { s: site:view() }";
    expectParseOk "individual:pick(x: true)";
    expectParseOk "individual:pick(x: true,)";
    expectParseOk "individual:pick(x: false)";
    expectParseOk "individual:pick(x: 42)";
    expectParseOk "individual:pick(x: 42.5)";
    expectParseOk "individual:pick(x: \"hello\")";
    expectParseOk "individual:pick(x: 1, y :2)";
    expectParseOk "individual:pick(x: 1, y: 2,)";

    expectParseOk ":meta";
    expectParseOk "individual:meta";
    expectParseOk "individual.nation:meta";

    expectParseOk "render(individual:pick)";
    expectParseOk "let name = render(individual:pick)";
    expectParseOk "render(individual:pick) { render(here:view) }";
    expectParseOk "let name = render(individual:pick) { render(here:view) }";
    expectParseOk "render(individual:pick) { let name = render(here:view) }";
    expectParseOk "render(individual:pick) { goto name }";
    expectParseOk "goto name";
    expectParseOk "render(individual:pick) { render(here:view), }";
    expectParseOk {|

      render(individual:pick) {
        render(here:view),
        render(site:view)
      }

    |};

    expectParseOk "null";

    expectParseOk "1 < 2";
    expectParseOk "1 > 2";
    expectParseOk "1 <= 2";
    expectParseOk "1 >= 2";
    expectParseOk "1 = 2";
    expectParseOk "1 != 2";
    expectParseOk "true && false";
    expectParseOk "true || false";

    expectParseQueryAndEq "true || false" Q.(
      or_ (bool true) (bool false)
    );

    expectParseQueryAndEq "true && false" Q.(
      and_ (bool true) (bool false)
    );

    expectParseQueryAndEq "true && false || true" Q.(
      or_ (and_ (bool true) (bool false)) (bool true)
    );

    expectParseQueryAndEq "true && (false || true)" Q.(
      and_ (bool true) (or_ (bool false) (bool true))
    );

    expectParseQueryAndEq "true || true && false" Q.(
      or_ (bool true) (and_ (bool true) (bool false))
    );

    expectParseQueryAndEq "1 > 2 && false" Q.(
      and_ (greaterThan (number 1.) (number 2.)) (bool false)
    );

    expectParseQueryAndEq "1 < 2 && false" Q.(
      and_ (lessThan (number 1.) (number 2.)) (bool false)
    );

    (** Mutations *)

    expectParseOk "individual:update{}";
    expectParseOk "individual:update{name: true}";
    expectParseOk "individual:update{name: true, surname: false}";
    expectParseOk "individual:update{name: true, identity: update { name: false }}";
    expectParseOk "individual:update{name: true, identity: create { name: false }}";
    expectParseOk "individual:create{}";
    expectParseOk "individual:create{name: true}";
    expectParseOk "individual:create{name: true, surname: false}";
    expectParseOk "individual:create{name: true, identity: update { name: false }}";
    expectParseOk "individual:create{name: true, identity: create { name: false }}";

    expectParseOk ":update{}";
    expectParseOk ":create{}";
    expectParseOk "/:update{}";
    expectParseOk "/:create{}";

  end;
