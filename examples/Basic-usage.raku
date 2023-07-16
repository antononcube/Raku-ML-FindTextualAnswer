#!/usr/bin/env raku
use v6.d;

use lib '.';
use lib './lib';

use ML::FindTextualAnswer;

my $llm = 'palm';
my $model = Whatever; #'text-davinci-003';

my $textShort = "Colors in preferences order : blue, red, green, white, pink, cherry, light brown.";
my $question = 'What is the favorite color?';
say "Single answer : ", find-textual-answer($textShort, $question, temperature => 0.5, :$llm);
say "Three answers : ", find-textual-answer($textShort, $question, 3, :$llm, max-tokens => 120).raku;

say "=" x 120;

my $textLong = q:to/END/;
Nikola Tesla (/ˈtɛslə/ TESS-lə; Serbian Cyrillic: Никола Тесла,[2] pronounced [nǐkola têsla];
[a] 10 July [O.S. 28 June] 1856 – 7 January 1943) was a Serbian-American[5][6][7] inventor, electrical engineer, mechanical engineer,
and futurist best known for his contributions to the design of the modern alternating current (AC) electricity supply system.[8]

Born and raised in the Austrian Empire, Tesla studied engineering and physics in the 1870s without receiving a degree,
gaining practical experience in the early 1880s working in telephony and at Continental Edison in the new electric power industry.

In 1884 he emigrated to the United States, where he became a naturalized citizen.
He worked for a short time at the Edison Machine Works in New York City before he struck out on his own.
With the help of partners to finance and market his ideas,
Tesla set up laboratories and companies in New York to develop a range of electrical and mechanical devices.
His alternating current (AC) induction motor and related polyphase AC patents, licensed by Westinghouse Electric in 1888,
earned him a considerable amount of money and became the cornerstone of the polyphase system which that company eventually marketed.
END

my @questions =
        ["What are the dates?",
         "What is person's full name?",
         "Where lived?",
        ];

my $res =
        find-textual-answer($textLong, @questions, 3,
                :$llm,
                :$model,
                temperature => 0.75,
                max-output-tokens => 400):pairs:!echo;

if $res ~~ Positional {
    .say for |$res;
} else {
    say $res;
}