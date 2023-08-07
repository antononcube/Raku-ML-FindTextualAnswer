#!/usr/bin/env raku
use v6.d;

use lib '.';
use lib './lib';

use ML::FindTextualAnswer;
use LLM::Functions;
use JSON::Fast;

my @queries = [
    'Make a classifier with the method RandomForest over the data dfTitanic; show precision and accuracy; plot True Positive Rate vs Positive Predictive Value.',
    'Make a recommender over the data frame dfOrders. Give the top 5 recommendations for the profile year:2022, type:Clothing, and status:Unpaid',
    'Create an LSA object over the text colletion aAbstracts; extract 40 topics; show statistical thesaurus for "notebook", "equation", "changes", and "prediction"',
    'Compute quantile regression for dfTS with interpolation order 3 and knots 12 for the probabilities 0.2, 0.4, and 0.9.'
];

my @wkflTypes = ('Classification', 'Latent Semantic Analysis', 'Quantile Regression', 'Recommendations').sort;

say "{ '=' x 10 } Using PaLM { '=' x 100 }";
for @queries {
    say $_;
    say llm-classify($_, @wkflTypes, llm-evaluator => llm-configuration('palm')):echo;
    say '-' x 60;
}


say "{ '=' x 10 } Using OpenAI { '=' x 98 }";
for @queries {
    say $_;
    say llm-classify($_, @wkflTypes, llm-evaluator => llm-configuration('openai', model => 'text-davinci-003'));
    say '-' x 60;
}