#!/usr/bin/env raku
use v6.d;

#use lib <. lib>;

use ML::FindTextualAnswer;

my $command = "Make a classifier with the method Random Forest over the data dfTitanic. Show Precision and Recall. Split the data with ratio 0.75; plot ROC functions PPV vs TPR.";

my @wkflTypes = ('Classification', 'Latent Semantic Analysis', 'Quantile Regression', 'Recommendations').sort;

for @wkflTypes.kv -> $k, $v { say "{$k + 1}) $v"; }

say find-textual-answer($command, @wkflTypes, llm => 'palm', request => 'which of these workflows characterizes it'):echo:pairs;

say '=' x 120;

my $question = @wkflTypes.pairs.map({ "{$_.key + 1}) {$_.value}" }).join("\n");

say $question;

my $res = find-textual-answer($command, $question, llm => 'palm', request => 'which of these workflows characterizes it', strip-with => 'NONE'):echo:pairs;

say do given $res {
    when $_ ~~ / ^ (\d+) / {
        my $index = $0.Str.Int;
        if 1 ≤ $index ≤ @wkflTypes.elems { @wkflTypes[$index-1] }
        else {
            note "Cannot deterimine the class label.";
            $0.Str
        }
    }
    default {

        my @clRes = @wkflTypes.grep(-> $lbl { $_.contains($lbl) });
        if @clRes {
            @clRes
        } else {
            note "Cannot deterimine the class label.";
            $_
        }
    }
}