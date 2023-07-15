use v6.d;

use ML::FindTextualAnswer::LLM::TextualAnswer;

unit module ML::FindTextualAnswer;



#===========================================================
#| Finding substrings that appear to be answers of questions.
our proto find-textual-answer(|) is export {*}

multi sub find-textual-answer(**@args, *%args) {
    return ML::FindTextualAnswer::LLM::TextualAnswer::Fetch(|@args, |%args);
}

