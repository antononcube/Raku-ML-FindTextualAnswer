use v6.d;

use lib '.';
use lib './lib';

use ML::FindTextualAnswer;
use LLM::Functions;
use Test;

my $llm-evaluator = llm-evaluator('PaLM');
my $echo = False;

plan *;

## 1
ok llm-textual-answer("racoon with perls in the style of Hannah Wilke",
        ['What style?', 'What about?'],
        :$llm-evaluator, :$echo);

## 2
my $text2 = 'make a classifier with the method RandomForest over the dataset dfTitanic; show accuracy and recall';
my @questions = ['which method?', 'which dataset?', 'what metrics to display?'];
ok llm-textual-answer($text2, @questions);

## 3
ok llm-textual-answer($text2, @questions, request => 'answer the questions', :$llm-evaluator, :$echo);

## 4
my $res4 = llm-textual-answer($text2, 'Which dataset?', llm-evaluator => llm-evaluator($llm-evaluator, model => 'chat-bison-001'), :$echo);
isa-ok $res4, Hash;

## 5
is-deeply $res4.keys.Array, ['error',];

## 6
isa-ok llm-textual-answer($text2, @questions,
        llm-evaluator => llm-evaluator(llm-evaluator('ChatPaLM'), model => 'chat-bison-001'), :$echo):pairs,
        Hash;

done-testing;