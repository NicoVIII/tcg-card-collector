import gleeunit
import gleeunit/should
import rules/depends_only_on

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn depends_only_on_rule_test() {
  should.equal(
    depends_only_on.allows(depends_only_on.Domain, depends_only_on.Application),
    False,
  )

  should.equal(
    depends_only_on.allows(depends_only_on.Application, depends_only_on.Domain),
    True,
  )

  should.equal(
    depends_only_on.allows(
      depends_only_on.Driver,
      depends_only_on.Infrastructure,
    ),
    False,
  )

  should.equal(
    depends_only_on.allows(
      depends_only_on.Composition,
      depends_only_on.Infrastructure,
    ),
    True,
  )
}
