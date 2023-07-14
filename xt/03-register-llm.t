use v6.d;

use lib '.';
use lib './lib';

use ML::FindTextualAnswer;
use ML::FindTextualAnswer::LLMFindTextualAnswer;

use WWW::PaLM::Models;
use WWW::PaLM::GenerateMessage;
use WWW::PaLM::GenerateText;
use Test;

my $llm = 'bard',
my $method = 'tiny';
my $model = 'text-bison-001';
my $max-tokens = 120;
my $echo = False;


plan *;

## 1
ok register-llm( :$llm, module => 'WWW::PaLM', default-model => $model,
        model-to-end-point-func => &palm-model-to-end-points,
        query-func => -> $model { palm-is-chat-completion-model($model) ?? &PaLMGenerateMessage !! &PaLMGenerateText });
## 2
my $text2 = 'make a classifier with the method RandomForest over the dataset dfTitanic; show accuracy and recall';
my @questions = ['which method?', 'which dataset?', 'what metrics to display?'];
ok find-textual-answer($text2, @questions, :$llm, :$max-tokens, :$model, :$method, :$echo);


done-testing;