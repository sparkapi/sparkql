v1.3.4, 20265-01-20
  * [BUGFIX] Validate limit for days and weekdays

v1.3.3, 2025-08-12
-------------------
  * [BUGFIX] Evaluator fix for Not regression

v1.3.2, 2025-08-06
-------------------
  * [BUGFIX] More Evaluator fixes
  * [BUGFIX] fixed the build.

v1.3.1, 2025-08-06
-------------------
  * [BUGFIX] Evaluator fix for Not expressions

v1.3.0, 2022-02-01
-------------------
  * [BUGFIX] Redesign FunctionResolver to better support other timezones

v1.2.8, 2021-08-11
-------------------
  * [IMPROVEMENT] all() function

v1.2.7, 2021-05-06
-------------------
  * [IMPROVEMENT] dayofweek(), dayofyear(), and weekdays() functions

v1.2.6, 2019-04-01
-------------------
  * [IMPROVEMENT] hours(), minutes(), and seconds() functions

v1.2.5, 2018-12-19
-------------------
  * [BUGFIX] Correctly handle arithmetic grouping

v1.2.4, 2018-12-13
-------------------
  * [IMPROVEMENT] Support decimal arithmetic
  * [BUGFIX] Correctly handle type checking with arithmetic

v1.2.3, 2018-12-05
-------------------
  * [IMPROVEMENT] Support Arithmetic Grouping and Negation

v1.2.2, 2018-11-28
-------------------
  * [IMPROVEMENT] Support Arithmetic: Add, Sub, Mul, Div, Mod

v1.2.1, 2018-10-09
-------------------
  * [BUGFIX] Check deepest function when type checking field arguments.

v1.2.0, 2018-09-24
-------------------
  * [IMPROVEMENT] Support Nested field functions via `field_manipulations` attribute.

v1.1.17, 2018-08-01
-------------------
  * [IMPROVEMENT] New Function: concat()

v1.1.16, 2018-07-26
-------------------
  * [IMPROVEMENT] New Function: cast()

v1.1.15, 2018-07-12
-------------------
  * [IMPROVEMENT] New Functions: ceiling(), floor()

v1.1.14, 2018-07-12
-------------------
  * [IMPROVEMENT] Allow Negation for integer and decimal literals
  * [IMPROVEMENT] New Functions: round(), substring(), trim()
  * [BUGFIX] `MIN_DATE_TIME` was increased to 1970

v1.1.13, 2018-06-27
-------------------
  * [IMPROVEMENT] New Functions: length(), mindatetime(), maxdatetime()

v1.1.12, 2018-06-26
-------------------
  * [IMPROVEMENT] New Function: indexof()

v1.1.11, 2018-03-30
-------------------
  * [BUGFIX] contains(), startswith(), endswith() are now case-sensitive

v1.1.10, 2018-01-05
-------------------
  * [IMPROVEMENT] Allow radius to take integer

v1.1.9, 2018-01-05
-------------------
  * [IMPROVEMENT] New function: wkt()

v1.1.8, 2017-11-30
-------------------
  * [BUGFIX] Properly coerce integer values to decimals when a function is used
    prior to the operator

v1.1.7, 2017-03-31
-------------------
  * [BUGFIX] Add missing require for StringScanner

v1.1.6, 2016-11-11
-------------------
  * [BUGFIX] Properly pad return strings from toupper/tolower with single quotes

v1.1.5, 2016-11-11
-------------------
  * [BUGFIX] Corrected levels for unary and conjunction elements of an expression

v1.1.4, 2016-11-11
-------------------
  * [IMPROVEMENT] New functions: contains(), startswith(), endswith()

v1.1.3, 2016-11-10
-------------------
  * [IMPROVEMENT] New functions: tolower() and toupper()

v1.1.2, 2016-11-08
-------------------
  * [IMPROVEMENT] New functions: year(), month(), day(), hour(), minute(), second(), and
    fractionalseconds().

v1.1.1, 2016-09-09
-------------------
  * [BUGFIX] Fix `Not` handling in the new Evaluation class

v1.1.0, 2016-07-28
-------------------
  * [IMPROVEMENT] Evaluation class for sparkql boolean algebra processing

v1.0.3, 2016-06-06
-------------------
  * [IMPROVEMENT] Expression limit lifted to 75 expressions

v1.0.2, 2016-04-26
-------------------
  * [IMPROVEMENT] Support for new range() function for character ranges

v1.0.1, 2016-02-24
-------------------
  * [IMPROVEMENT] Support scientific notation for floating point numbers

v1.0.0, 2016-02-11
-------------------
  * [IMPROVEMENT] function support for fields (delayed resolution). Backing systems must
    implement necessary function behaviour.
  * Drop support for ruby 1.8.7. Georuby dropped support several years back and
    this drop allows us to pick up newer update allows us to stay in sync with
    that gems development

v0.3.24, 2016-01-05
-------------------

  * [BUGFIX] Support opening Not operator for "Not (Not ...)" expressions.

v0.3.23, 2015-10-09
-------------------

  * [IMPROVEMENT] Add regex function for character types

v0.3.22, 2015-10-09
-------------------

  * [IMPROVEMENT] Record sparkql and nested errors for fields that embed sparkql

v0.3.21, 2015-09-24
-------------------

  * [IMPROVEMENT] Record token index and current token in lexer, for error reporting

v0.3.20, 2015-04-14
-------------------

  * [BUGFIX] Allow seconds for ISO-8601

v0.3.18, 2015-04-10
-------------------

  * [BUGFIX] Better support for ISO-8601

