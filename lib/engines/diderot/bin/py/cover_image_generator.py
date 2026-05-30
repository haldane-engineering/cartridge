import json
import base64
import secrets

from PIL import Image, ImageDraw, ImageFont
from io import BytesIO
from rembg import remove

COVER_IMAGE_DIMENSIONS_HEIGHT = 2048
COVER_IMAGE_DIMENSIONS_BREADTH = 1444
OVERLAY_TRANSPARENCY = 128
# Hero images should be 20% of the cover. I assume this will change on iterations
HERO_IMAGE_FRACTION = 20 / 100
LEAGUE_INSIGNIA_FRACTION = 5 / 100
TICKER_FONT_SIZE = 40
SCORE_FONT_SIZE = 15
TICKER_RGBA = (0, 0, 0)

class CoverImageGenerator:
    def __init__(self, params):
        self.__params = json.loads(params)
        pass
    
    def generate(self):
        # assumption is the participants are arranged as they should be displayed. The nba convention
        # is to have the away team first and home team later, but this is delegated to the caller to handle. 
        participants = [GameParticipant(**p) for p in self.__params['participants']]
        game_context = GameContext(**self.__params['game_context'])
        bg_image = self.__img_from_base64(game_context.background_image64).convert('RGBA')
        cover_sizes = (COVER_IMAGE_DIMENSIONS_HEIGHT, COVER_IMAGE_DIMENSIONS_BREADTH)
        bg_image = bg_image.resize(cover_sizes, resample=Image.Resampling.LANCZOS).convert('RGBA')
        # https://pillow.readthedocs.io/en/stable/handbook/concepts.html#concept-filters:~:text=image%20is%20used.-,Resampling,-.LANCZOS
        bg_overlay = Image.new('RGBA', cover_sizes)
        # Make overlay 50% transparent
        bg_overlay.putalpha(OVERLAY_TRANSPARENCY)
        # 0.0 as the alpha,. so this returns a copy of the first image
        final_background = Image.blend(bg_image, bg_overlay, 0.0)
        hero_images = [self.__img_from_base64(participant.hero_image64) for participant in participants]
        # transfoorm the hero images i.e. resize to [20% - adjustable] of the standard cover dimensions and remove the
        # background
        for index, image in enumerate(hero_images):
            pasteable_image = self.__remove_bg_and_regenerate(image.resize((HERO_IMAGE_FRACTION * COVER_IMAGE_DIMENSIONS_HEIGHT, 
                                            HERO_IMAGE_FRACTION * COVER_IMAGE_DIMENSIONS_BREADTH), 
                                           resample=Image.Resampling.LANCZOS))
            # The box argument is either a 2-tuple giving the upper left corner, 
            # a 4-tuple defining the left, upper, right, and lower pixel coordinate, or None
            left_position_coords = (10, 10, 0, 0)
            final_background.paste(pasteable_image, left_position_coords if index == 0 else left_position_coords[::-1])
        # Place the logo
        insignia_dimensions = (LEAGUE_INSIGNIA_FRACTION * COVER_IMAGE_DIMENSIONS_BREADTH, 
                                           LEAGUE_INSIGNIA_FRACTION * COVER_IMAGE_DIMENSIONS_HEIGHT)
        league_insignia = self.__img_from_base64(game_context.league_image64)
        league_insignia = self.__remove_bg_and_regenerate(league_insignia.resize(insignia_dimensions, resample=Image.Resampling.LANCZOS))
        # place the league's logo right at the center of the background, just above the border top of the hero images 
        final_background.paste(league_insignia, ( 0.5 * COVER_IMAGE_DIMENSIONS_BREADTH, 5, 0, 0))
        # final section to write the text, save the image to the dest path and write the callers -> uses argparser to get
        # the json string from the terminal.
        # We place the team tickers -> Gsw vs CLe in a vertical stack -> with the vs text centered 
        d = ImageDraw.Draw(final_background)
        for index, participant in enumerate(participants):
            font = ImageFont.truetype("Pillow/Tests/fonts/FreeMono.ttf", TICKER_FONT_SIZE)
            # (Left, Upper, Right, Lower)
            d.text((0.5 * COVER_IMAGE_DIMENSIONS_BREADTH, (.4 if index == 0 else .6) * COVER_IMAGE_DIMENSIONS_HEIGHT), participant.team_ticker, font=font, fill=(TICKER_RGBA))
            if index == 0:    
                font = ImageFont.truetype("Pillow/Tests/fonts/FreeMono.ttf", TICKER_FONT_SIZE * 0.6)
                d.text((0.5 * COVER_IMAGE_DIMENSIONS_BREADTH, .5 * COVER_IMAGE_DIMENSIONS_HEIGHT), 'VS', font=font, fill=(TICKER_RGBA))
        
        # I'm tempted to insert the scores here -> but let me see how it turns out first
        # write the score at the top right
        score = (" - ").join([participant.total_points in participants])
        font = ImageFont.truetype("Pillow/Tests/fonts/FreeMono.ttf", SCORE_FONT_SIZE)
        x_position = COVER_IMAGE_DIMENSIONS_BREADTH - (.8 * COVER_IMAGE_DIMENSIONS_BREADTH)
        d.text((x_position, 10), score, font=font, fill=(TICKER_RGBA))
        identifier = secrets.token_hex(16)
        final_background.save(f"{game_context.destination_folder}/{identifier}.jpg")
        
        
    def __img_from_base64(self, base64_string):
        return Image.open(BytesIO(base64.b64decode(base64_string)))

    def __remove_bg_and_regenerate(self, image):
        output = remove(image)
        return Image.open(BytesIO(output)).convert('RGBA')
    
       
class GameParticipant:
    def __init__(self, opts):
        self.team_ticker = opts['team_ticker']
        self.team_name = opts['team_name']
        self.hero_image64 = opts['hero_image_base64']
        self.total_points = opts['total_points_scored']

class GameContext:
    def __init__(self, options):
        self.destination_folder = options['dest']
        self.background_image64 = options['background_image_base64']
        self.league_image64 = options['league_image_base64']