# lispell
A simple excel engine, where every cell contains a lisp expression

The name is a combination of lisp and cell, so we get lispell, because it also has the word spell in it

## File Format

input files are basically csv files were every cell has a lisp expression which looks like that

```csv
(+ 1 2), 2, (- a1 b1)
(* 3 2 c1)
(if (== a2 6) (+ 1 a1) (/ b1 4))
```
which outputs:

```csv
3, 2, 1,
6,
4,
```

## Lisp dialect

math operations
```lisp
(+ 1 2 3 4 5) ; 15
(- 15 5 2) ; 8
(/ 20 5 2) ; 2
(* 5 5) ; 25
```

boolean operations
```lisp
5
4
(== 4 a2 4) ; true
(== 4 a2 a1) ; false
```

strings
```lisp
"Hello world", "!", "lispell"
```

if
```
(if (== 1 1) 1 "It broke")
```

functions
```
(fn (a b) (- a b)), (a1 5 2) ; define then call
((fn (a b) (+ a b)) 10 10) ; use a "lambda" and call it directly
```

# TODOS

- [ ] add labels to make working with variables more comfortable (e.g. `add: (fn (a b) (+ a b))`)
- [ ] add list support in the lisp (list processor) dialect
- [ ] add ability to work on ranges of cells (e. g. `a1 : a5`)
- [ ] add comments
- [ ] more boolean operations