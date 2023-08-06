use v6.d;

use lib '.';
use lib './lib';

use LLM::Functions;
use ML::FindTextualAnswer;
use Test;

my $llm = 'palm',
my $method = 'tiny';
my $model = 'text-bison-001';
my $max-tokens = 120;
my $echo = False;
my $conf = llm-configuration('PaLM', :$model, :$max-tokens, :$method);


plan *;

## 1
ok find-textual-answer("racoon with perls in the style of Hannah Wilke",
        ['What style?', 'What about?'],
        :$llm, :$max-tokens, :$model, :$method);

## 2
my $text2 = 'make a classifier with the method RandomForest over the dataset dfTitanic; show accuracy and recall';
my @questions = ['which method?', 'which dataset?', 'what metrics to display?'];
ok find-textual-answer($text2, @questions, llm-evaluator => $conf, :$echo);

## 3
ok find-textual-answer($text2, @questions, request => 'answer the questions', llm-evaluator => $conf, :$echo);

## 4
ok find-textual-answer($text2, 'Which dataset?', model => 'chat-bison-001', llm-evaluator => $conf, :$echo);

## 5
isa-ok find-textual-answer($text2, @questions,
        llm-evaluator => llm-configuration($conf, model => 'chat-bison-001',), :$echo):pairs,
        Hash;

## 6
my $text6 = "My color preferences are given by the following order: blue, red, green, white, pink, cherry, light brown.";
my $question6 = 'What is the favorite color?';
ok find-textual-answer($text6, $question6, 3, llm-evaluator => $conf, :$echo);

## 7
isa-ok find-textual-answer($text6, $question6, llm-evaluator => $conf, :$echo),
        Str,
        'single string answer for single question';

done-testing;