# Potential problems

## Questions over questions

If the given text itself is a question certain LLM models might decide to answer it which in combination with
other parameters can be produce failing results.

For example consider this classifier function that might be used in a conversational agent loop:

```perl6
my &is-start-over-request = -> $txt, *%args { 
  llm-textual-answer($txt, 'Is the given text an imperative command that asks the process to "start over"? True / False', |%args)
}
```

If too few tokens are given we get failure:

```perl6
my $conf = llm-configuration('chatgpt', model => 'gpt-3.5-turbo', max-tokens => 300);
&is-start-over-request("How many filter refinements we did so far?", :echo, :pairs, llm-evaluator => $conf);
```

One fix is to use more advanced model and/or large number of tokens:

```perl6
&is-start-over-request("How many filter refinements we did so far?", :echo, :pairs, e => llm-configuration($conf, max-tokens => 4096));
```

Another fix is to put the question in quotes:

```perl6
&is-start-over-request("«How many filter refinements we did so far?»", :echo, :pairs, e => $conf);
```

That is why since `ver<0.2.6>` the function `ML::FindTextualAnswer::LLM::TextualAnswer::Function` has
text separator parameters, `sep-text-begin` and `sep-text-end`.
By default those separators are Markdown code fences for "text", 
i.e. `` ```text `` and `` ``` ``, respectively.