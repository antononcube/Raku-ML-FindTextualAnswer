use v6.d;

use lib '.';
use lib './lib';

use LLM::Functions;
use ML::FindTextualAnswer;
use Test;

my $method = 'tiny';
my $model1 = 'text-curie-001';
my $max-tokens = 120;
my $conf1 = llm-configuration('OpenAI', :$model1, :$max-tokens, :$method);

my $model2 = 'gpt-3.5-turbo';
my $conf2 = llm-configuration('ChatGPT', :$model2, :$max-tokens, :$method);

plan *;

## 1
ok find-textual-answer(
        "racoon with perls in the style of Hannah Wilke",
        ['What style?', 'What about?'],
        finder => llm-evaluator($conf1));

## 2
my $text2 = 'make a classifier with the method RandomForest over the dataset dfTitanic; show accuracy and recall';
my @questions2 = ['which method?', 'which dataset?', 'what metrics to display?'];
ok find-textual-answer($text2, @questions2, finder =>  llm-evaluator($conf1));

## 3
ok find-textual-answer($text2, @questions2, request => 'answer the questions', finder => llm-evaluator($conf1));

## 4
ok find-textual-answer($text2, 'Which dataset?', finder => llm-evaluator(llm-configuration($conf1, model => 'gpt-3.5-turbo-0301')));

## 5
isa-ok find-textual-answer($text2, @questions2, finder => llm-evaluator($conf2)):pairs, Hash;

done-testing;
