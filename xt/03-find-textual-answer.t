use v6.d;

use lib '.';
use lib './lib';

use ML::FindTextualAnswer;
use LLM::Functions;
use Test;

my $llm-evaluator = Whatever;
my $echo = False;

plan *;

## 1
my $text2 = 'make a classifier with the method RandomForest over the dataset dfTitanic; show accuracy and recall';
my @questions = ['which method?', 'which dataset?', 'what metrics to display?'];
ok find-textual-answer($text2, @questions);

## 2
ok find-textual-answer("racoon with perls in the style of Hannah Wilke",
        ['What style?', 'What about?'],
        :$llm-evaluator, :$echo);

done-testing;