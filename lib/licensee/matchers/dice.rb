# frozen_string_literal: true

VIM_CONFIDENCE_TOLERANCE = 0.03

module Licensee
  module Matchers
    class Dice < Licensee::Matchers::Matcher
      # Return the first potential license that is more similar
      # than the confidence threshold
      def match
        @match ||= if matches.empty?
          nil
        else
          matches.first[0]
        end
      end

      # Licenses that may be a match for this file.
      # To avoid false positives:
      #
      # 1. Creative commons licenses cannot be matched against license files
      #    that begin with the title of a non-open source CC license variant
      # 2. The percentage change in file length may not exceed the inverse
      #    of the confidence threshold
      def potential_matches
        @potential_matches ||= begin
          super.select do |license|
            if license.creative_commons? && file.potential_false_positive?
              false
            else
              max_delta = license.max_delta
              tolerance = if license.vim? then VIM_CONFIDENCE_TOLERANCE else 0 end

              if tolerance > 0
                inverse_confidence_threshold = Licensee.inverse_confidence_threshold
                max_delta = (max_delta * [1, tolerance + inverse_confidence_threshold].min / inverse_confidence_threshold).to_i
              end

              license.wordset && license.length_delta(file) <= max_delta
            end
          end
        end
      end
      alias potential_licenses potential_matches

      def matches_by_similarity
        @matches_by_similarity ||= begin
          matches = potential_matches.map do |potential_match|
            [potential_match, potential_match.similarity(file)]
          end
          matches.sort_by { |_, similarity| similarity }.reverse
        end
      end
      alias licenses_by_similarity matches_by_similarity

      def matches
        @matches ||= matches_by_similarity.select do |license, similarity|
          tolerance = if license.vim? then VIM_CONFIDENCE_TOLERANCE * 100 else 0 end
          similarity >= [0, minimum_confidence - tolerance].max
        end
      end

      # Confidence that the matched license is a match
      def confidence
        @confidence ||= match ? file.similarity(match) : 0
      end

      private

      def minimum_confidence
        Licensee.confidence_threshold
      end
    end
  end
end
