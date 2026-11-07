import json
import base64
import secrets
import os

from PIL import Image, ImageDraw, ImageFont, ImageOps
from io import BytesIO
from rembg import remove

# landscape cover
COVER_IMAGE_WIDTH = 2048
COVER_IMAGE_HEIGHT = 1444
OVERLAY_TRANSPARENCY = 128
# Hero images should be 20% of the cover. I assume this will change on iterations
HERO_IMAGE_FRACTION = 70 / 100
# make space for the logo at the center
HERO_IMAGE_WIDTH_FRACTION = 35 / 100
LEAGUE_INSIGNIA_FRACTION = 18 / 100
TICKER_FONT_SIZE = 650
SCORE_FONT_SIZE = 850
# px between the bottom of the lower ticker and the top of the scheduled_at text
SCHEDULED_AT_TICKER_GAP = 180
# Bright Yellow, really like it
TICKER_RGBA = (255, 223, 32)
# TICKER_RGBA = (123, 241, 168)
TICKER_DIVIDER_RGBA = (255, 255, 255)
TICKER_FONT_FILE = 'atlanta-college.regular.ttf'
SCHEDULED_AT_FONT_FILE = 'Baserona.ttf'
SCHEDULED_AT_RGBA = (253, 199, 69)

class CoverImageGenerator:
    def __init__(self, params):
        self.__params = json.loads(params)
        pass
    
    def generate(self):
        # assumption is the participants are arranged as they should be displayed. The nba convention
        # is to have the away team first and home team later, but this is delegated to the caller to handle. 
        participants = [GameParticipant(p) for p in self.__params['participants']]
        game_context = GameContext(self.__params['game_context'])
        bg_image = self.__img_from_base64(game_context.background_image64).convert('RGBA')
        # PIL sizes are (width, height)
        cover_sizes = (COVER_IMAGE_WIDTH, COVER_IMAGE_HEIGHT)
        bg_image = bg_image.resize(cover_sizes, resample=Image.Resampling.LANCZOS).convert('RGBA')
        # https://pillow.readthedocs.io/en/stable/handbook/concepts.html#concept-filters:~:text=image%20is%20used.-,Resampling,-.LANCZOS
        bg_overlay = Image.new('RGBA', cover_sizes)
        # Make overlay 50% transparent
        bg_overlay.putalpha(OVERLAY_TRANSPARENCY)
        # 0.0 as the alpha,. so this returns a copy of the first image
        final_background = Image.blend(bg_image, bg_overlay, 0.9)
        hero_images = [self.__img_from_base64(participant.hero_image64) for participant in participants]
        # transform the hero images i.e. fill the full height of the cover at the fixed hero width. ImageOps.fit scales
        # (keeping the aspect ratio) until both dimensions are covered, then crops the overflow -> centered horizontally,
        # anchored to the top so the player's head is kept. Then remove the background
        for index, image in enumerate(hero_images):
            pasteable_image = self.__remove_bg_and_regenerate(ImageOps.fit(image, (int(HERO_IMAGE_WIDTH_FRACTION * COVER_IMAGE_WIDTH),
                                            COVER_IMAGE_HEIGHT),
                                           method=Image.Resampling.LANCZOS, centering=(0.5, 0.2)))
            # The box argument is either a 2-tuple giving the upper left corner,
            # a 4-tuple defining the left, upper, right, and lower pixel coordinate, or None
            left_position_coords = (10, 0)
            right_position_coords = (final_background.width - pasteable_image.width - 10, 0)
            # pass the image as its own mask so the removed background stays transparent
            final_background.paste(pasteable_image, left_position_coords if index == 0 else right_position_coords,
                                   mask=pasteable_image)
        # Place the logo
        insignia_dimensions = (int(LEAGUE_INSIGNIA_FRACTION * COVER_IMAGE_WIDTH),
                                           int(LEAGUE_INSIGNIA_FRACTION * COVER_IMAGE_HEIGHT))
        league_insignia = self.__img_from_base64(game_context.league_image64)
        league_insignia = self.__remove_bg_and_regenerate(ImageOps.contain(league_insignia, insignia_dimensions,method=Image.Resampling.LANCZOS))
       
        # place the league's logo right at the center of the background, just above the border top of the hero images 
        final_background.paste(league_insignia, ((COVER_IMAGE_WIDTH - league_insignia.width) // 2, 3), mask=league_insignia)
        
        # final section to write the text, save the image to the dest path and write the callers -> uses argparser to get
        # the json string from the terminal.
        d = ImageDraw.Draw(final_background)
        font_path = os.path.abspath(os.path.join(os.path.dirname(__file__), TICKER_FONT_FILE))
        font = ImageFont.truetype(font_path, size=int(TICKER_FONT_SIZE * 0.6), encoding="unic")
        divider_font = ImageFont.truetype(font_path, size=int(TICKER_FONT_SIZE * 0.23), encoding="unic")
        for index, participant in enumerate(participants):
            # font = ImageFont.load_default(size=TICKER_FONT_SIZE)
            # anchor 'mm' -> (x, y) is the middle of the text, so it's centered regardless of ticker length
            ticker_coords = (0.5 * COVER_IMAGE_WIDTH, (.35 if index == 0 else .63) * COVER_IMAGE_HEIGHT)
            d.text(ticker_coords, participant.team_ticker, font=font, fill=(TICKER_RGBA), anchor='mm')
            # (left, top, right, bottom) of the last drawn ticker -> used to place the scheduled_at underneath it
            bottom_ticker_box = d.textbbox(ticker_coords, participant.team_ticker, font=font, anchor='mm')
            if index == 0:
                d.text((0.5 * COVER_IMAGE_WIDTH, .49 * COVER_IMAGE_HEIGHT), 'VS', font=divider_font, fill=(TICKER_DIVIDER_RGBA), anchor='mm')

        # I'm tempted to insert the scores here -> but let me see how it turns out first
        # score = (" - ").join(str(participant.total_points) for participant in participants)
        font_path = os.path.abspath(os.path.join(os.path.dirname(__file__), SCHEDULED_AT_FONT_FILE))
        font = ImageFont.truetype(font_path, size=SCORE_FONT_SIZE, encoding="unic")
        ticker_width = bottom_ticker_box[2] - bottom_ticker_box[0]
        scheduled_at_width = d.textlength(game_context.game_scheduled_at, font=font)
        if scheduled_at_width > ticker_width:
            font = ImageFont.truetype(font_path, size=int((SCORE_FONT_SIZE * ticker_width / scheduled_at_width) * 1.2), encoding="unic")
        d.text((0.5 * COVER_IMAGE_WIDTH, bottom_ticker_box[3] + SCHEDULED_AT_TICKER_GAP), game_context.game_scheduled_at,
               font=font, fill=(SCHEDULED_AT_RGBA), anchor='mt')
        final_background.convert('RGB').save(f"{game_context.destination_folder}/cover.jpg")
        
        
    def __img_from_base64(self, base64_string):
        return Image.open(BytesIO(base64.b64decode(base64_string)))

    def __remove_bg_and_regenerate(self, image):
        # rembg returns the same type it's given -> PIL Image in, PIL Image out
        return remove(image).convert('RGBA')
    
       
class GameParticipant:
    def __init__(self, opts):
        self.team_ticker = opts['team_ticker']
        self.team_name = opts['team_name']
        self.hero_image64 = opts['hero_image_base64']
        self.total_points = opts['total_points_scored']

class GameContext:
    def __init__(self, options):
        self.destination_folder = options['destination']
        self.background_image64 = options['background_image_base64']
        self.league_image64 = options['league_image_base64']
        self.game_scheduled_at = options['game_scheduled_at']
        
if __name__ == "__main__":
    import sys
    CoverImageGenerator(sys.stdin.read()).generate()
