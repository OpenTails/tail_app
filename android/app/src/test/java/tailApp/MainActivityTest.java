package tailApp;

import androidx.test.rule.ActivityTestRule;

import com.codel1417.tailApp.MainActivity;

import org.junit.Rule;
import org.junit.runner.RunWith;

import dev.flutter.plugins.integration_test.FlutterTestRunner;

@RunWith(FlutterTestRunner.class)
public class MainActivityTest {
    @Rule
    public ActivityTestRule<MainActivity> rule = new ActivityTestRule<>(MainActivity.class, true, false);
}